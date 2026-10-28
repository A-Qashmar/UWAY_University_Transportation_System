using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UWAY.Api.Auth;
using UWAY.Api.Contracts;
using UWAY.Api.Data;
using UWAY.Api.Models;
using UWAY.Api.Services;

namespace UWAY.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/trips")]
public sealed class TripsController(
    UwayDbContext database,
    TripNotificationService notifications,
    UserNotificationService inbox,
    PassengerAccess passengerAccess) : ControllerBase
{
    [HttpGet]
    [Authorize(Policy = "PassengerOrAdmin")]
    public async Task<ActionResult<IReadOnlyList<TripResponse>>> GetAll(CancellationToken cancellationToken)
    {
        var query = QueryTrips();
        if (User.IsInRole("Passenger"))
        {
            // Cancelled and finished trips stay visible so a passenger can still
            // report a problem; finished trips are listed for 14 days.
            var gender = await passengerAccess.GetGenderAsync(User, cancellationToken);
            if (gender is null)
                return NoPassengerProfile();
            query = query.Where(trip => trip.Audience == gender);
            var finishedSince = DateTimeOffset.UtcNow.AddDays(-14);
            query = query.Where(trip => trip.Status != TripStatus.Finished ||
                (trip.EndedAtUtc != null && trip.EndedAtUtc >= finishedSince));
        }

        var trips = await query
            .OrderBy(trip => trip.DepartureAtUtc)
            .ToListAsync(cancellationToken);
        var includeAssignments = !User.IsInRole("Passenger");
        return Ok(trips.Select(trip => ToResponse(trip, includeAssignments)).ToList());
    }

    [HttpGet("assigned")]
    [Authorize(Policy = "DriverOnly")]
    public async Task<ActionResult<IReadOnlyList<TripResponse>>> GetAssigned(CancellationToken cancellationToken)
    {
        if (!int.TryParse(User.FindFirst(UwayClaimTypes.DriverId)?.Value, out var driverId) || driverId <= 0)
            return Forbid();

        var trips = await QueryTrips()
            .Where(trip => trip.DriverId == driverId)
            .OrderBy(trip => trip.DepartureAtUtc)
            .ToListAsync(cancellationToken);
        return Ok(trips.Select(trip => ToResponse(trip)).ToList());
    }

    [HttpGet("{id:guid}")]
    [Authorize(Policy = "PassengerDriverOrAdmin")]
    public async Task<ActionResult<TripResponse>> GetById(Guid id, CancellationToken cancellationToken)
    {
        var trip = await QueryTrips().SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (trip is not null && User.IsInRole("Driver") && !IsAssignedDriver(trip))
            return Forbid();
        if (trip is not null && User.IsInRole("Passenger"))
        {
            var gender = await passengerAccess.GetGenderAsync(User, cancellationToken);
            if (gender is null)
                return NoPassengerProfile();
            if (trip.Audience != gender)
                return NotFound();
        }
        return trip is null
            ? NotFound()
            : Ok(ToResponse(trip, includeAssignments: !User.IsInRole("Passenger")));
    }

    [HttpPost]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<TripResponse>> Create(TripRequest request, CancellationToken cancellationToken)
    {
        if (request.DepartureAtUtc == default || request.DepartureAtUtc.Offset != TimeSpan.Zero)
            return Invalid("DepartureAtUtc", "Provide a departure time in UTC with a Z suffix or +00:00 offset.");

        var validation = await ValidateReferences(request, cancellationToken);
        if (validation is not null)
            return BadRequest(validation);

        var trip = new Trip
        {
            Id = Guid.NewGuid(),
            RouteId = request.RouteId,
            BusId = request.BusId,
            DriverId = request.DriverId,
            DepartureAtUtc = request.DepartureAtUtc,
            Audience = request.Audience,
            Status = TripStatus.Scheduled
        };
        database.Trips.Add(trip);

        try
        {
            await database.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception) when (DatabaseErrorResponses.IsConstraintViolation(exception))
        {
            return DatabaseErrorResponses.ConstraintConflict(this, exception);
        }

        await LoadReferences(trip, cancellationToken);
        await inbox.NotifyDriverAsync(trip.DriverId, UserNotificationTypes.TripAssigned, "New trip assigned",
            UserNotificationService.Describe(trip), $"trip-assigned:{trip.Id}:{trip.DriverId}", trip.Id, cancellationToken);
        await database.SaveChangesAsync(cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = trip.Id }, ToResponse(trip));
    }

    [HttpPut("{id:guid}")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<TripResponse>> Update(Guid id, TripRequest request, CancellationToken cancellationToken)
    {
        if (request.DepartureAtUtc == default || request.DepartureAtUtc.Offset != TimeSpan.Zero)
            return Invalid("DepartureAtUtc", "Provide a departure time in UTC with a Z suffix or +00:00 offset.");

        var trip = await LoadTripForUpdate(id, cancellationToken);
        if (trip is null)
            return NotFound();
        if (trip.Status != TripStatus.Scheduled || trip.IsCancelled)
            return StateConflict("Only a scheduled, uncancelled trip can be edited.");

        var validation = await ValidateReferences(request, cancellationToken);
        if (validation is not null)
            return BadRequest(validation);

        var hasActiveIntents = await database.TripIntents.AnyAsync(
            intent => intent.TripId == id && intent.CancelledAtUtc == null, cancellationToken);
        if (hasActiveIntents && (request.RouteId != trip.RouteId || request.Audience != trip.Audience))
            return StateConflict("Passengers have already joined this trip, so its route and audience cannot change. Cancel the trip and create a new one instead.");

        var previousDriverId = trip.DriverId;
        trip.RouteId = request.RouteId;
        trip.BusId = request.BusId;
        trip.DriverId = request.DriverId;
        trip.DepartureAtUtc = request.DepartureAtUtc;
        trip.Audience = request.Audience;
        trip.Version++;

        try
        {
            await database.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            return StateConflict("Another request changed this trip. Reload it before trying again.");
        }
        catch (DbUpdateException exception) when (DatabaseErrorResponses.IsConstraintViolation(exception))
        {
            return DatabaseErrorResponses.ConstraintConflict(this, exception);
        }

        await LoadReferences(trip, cancellationToken);
        var stamp = DateTimeOffset.UtcNow.UtcTicks;
        if (previousDriverId != trip.DriverId)
        {
            await inbox.NotifyDriverAsync(previousDriverId, UserNotificationTypes.TripChanged, "Trip reassigned",
                $"{UserNotificationService.Describe(trip)} is no longer assigned to you.", $"trip-removed:{trip.Id}:{stamp}", trip.Id, cancellationToken);
            await inbox.NotifyDriverAsync(trip.DriverId, UserNotificationTypes.TripAssigned, "New trip assigned",
                UserNotificationService.Describe(trip), $"trip-assigned:{trip.Id}:{trip.DriverId}", trip.Id, cancellationToken);
        }
        else
        {
            await inbox.NotifyDriverAsync(trip.DriverId, UserNotificationTypes.TripChanged, "Trip details changed",
                $"Check the updated time or bus for {UserNotificationService.Describe(trip)}.", $"trip-changed:{trip.Id}:{stamp}", trip.Id, cancellationToken);
        }
        await database.SaveChangesAsync(cancellationToken);
        return Ok(ToResponse(trip));
    }

    [HttpPost("{id:guid}/start")]
    [Authorize(Policy = "DriverOrAdmin")]
    public async Task<ActionResult<TripResponse>> Start(Guid id, CancellationToken cancellationToken)
    {
        var trip = await LoadTripForUpdate(id, cancellationToken);
        if (trip is null)
            return NotFound();
        string? error;
        if (User.IsInRole("Admin"))
        {
            if (!trip.TryStartAsAdmin(DateTimeOffset.UtcNow, out error))
                return StateConflict(error);
        }
        else
        {
            if (!IsAssignedDriver(trip))
                return Forbid();
            if (!trip.TryStart(GetDriverId(), DateTimeOffset.UtcNow, out error))
                return StateConflict(error);
        }

        await notifications.QueueTripEventAsync(trip, TripNotificationType.TripStarted, cancellationToken);
        if (User.IsInRole("Driver"))
            await inbox.NotifyAdminsAsync(UserNotificationTypes.TripStarted, "Trip started",
                $"{trip.Driver?.FullName ?? "The driver"} started {UserNotificationService.Describe(trip)}.", $"trip-started:{trip.Id}", trip.Id, cancellationToken);
        else
            await inbox.NotifyDriverAsync(trip.DriverId, UserNotificationTypes.TripStarted, "Trip started by the admin",
                UserNotificationService.Describe(trip), $"trip-started-admin:{trip.Id}", trip.Id, cancellationToken);
        return await SaveStateChange(trip, cancellationToken);
    }

    [HttpPost("{id:guid}/end")]
    [Authorize(Policy = "DriverOrAdmin")]
    public async Task<ActionResult<TripResponse>> End(Guid id, CancellationToken cancellationToken)
    {
        var trip = await LoadTripForUpdate(id, cancellationToken);
        if (trip is null)
            return NotFound();
        string? error;
        if (User.IsInRole("Admin"))
        {
            if (!trip.TryEndAsAdmin(DateTimeOffset.UtcNow, out error))
                return StateConflict(error);
        }
        else
        {
            if (!IsAssignedDriver(trip))
                return Forbid();
            if (!trip.TryEnd(GetDriverId(), DateTimeOffset.UtcNow, out error))
                return StateConflict(error);
        }

        await notifications.QueueTripEventAsync(trip, TripNotificationType.TripCompleted, cancellationToken);
        if (User.IsInRole("Driver"))
            await inbox.NotifyAdminsAsync(UserNotificationTypes.TripFinished, "Trip finished",
                $"{trip.Driver?.FullName ?? "The driver"} finished {UserNotificationService.Describe(trip)}.", $"trip-finished:{trip.Id}", trip.Id, cancellationToken);
        else
            await inbox.NotifyDriverAsync(trip.DriverId, UserNotificationTypes.TripFinished, "Trip finished by the admin",
                UserNotificationService.Describe(trip), $"trip-finished-admin:{trip.Id}", trip.Id, cancellationToken);
        return await SaveStateChange(trip, cancellationToken);
    }

    [HttpPost("{id:guid}/delay")]
    [Authorize(Policy = "DriverOrAdmin")]
    public async Task<ActionResult<TripResponse>> Delay(Guid id, DelayTripRequest request, CancellationToken cancellationToken)
    {
        var trip = await LoadTripForUpdate(id, cancellationToken);
        if (trip is null)
            return NotFound();
        if (User.IsInRole("Driver") && !IsAssignedDriver(trip))
            return Forbid();
        if (!trip.TryDelay(request.DelayMinutes, request.Reason, out var error))
            return StateConflict(error);

        await notifications.QueueTripEventAsync(trip, TripNotificationType.TripDelayed, cancellationToken);
        if (User.IsInRole("Driver"))
            await inbox.NotifyAdminsAsync(UserNotificationTypes.TripDelayed, "Driver reported a delay",
                $"{trip.Driver?.FullName ?? "The driver"}: {UserNotificationService.Describe(trip)} is delayed {trip.DelayMinutes} min. {trip.DelayReason}",
                $"trip-delayed:{trip.Id}:{DateTimeOffset.UtcNow.UtcTicks}", trip.Id, cancellationToken);
        else
            await inbox.NotifyDriverAsync(trip.DriverId, UserNotificationTypes.TripDelayed, "Trip marked as delayed",
                $"{UserNotificationService.Describe(trip)} · {trip.DelayMinutes} min. {trip.DelayReason}",
                $"trip-delayed:{trip.Id}:{DateTimeOffset.UtcNow.UtcTicks}", trip.Id, cancellationToken);
        return await SaveStateChange(trip, cancellationToken);
    }

    [HttpPost("{id:guid}/cancel")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<TripResponse>> Cancel(Guid id, CancelTripRequest request, CancellationToken cancellationToken)
    {
        var trip = await LoadTripForUpdate(id, cancellationToken);
        if (trip is null)
            return NotFound();
        if (!trip.TryCancel(request.Reason, DateTimeOffset.UtcNow, out var error))
            return StateConflict(error);

        await notifications.QueueTripEventAsync(trip, TripNotificationType.TripCancelled, cancellationToken);
        await inbox.NotifyDriverAsync(trip.DriverId, UserNotificationTypes.TripCancelled, "Trip cancelled",
            $"{UserNotificationService.Describe(trip)}. {trip.CancellationReason}", $"trip-cancelled:{trip.Id}:{trip.CancelledAtUtc?.UtcTicks}", trip.Id, cancellationToken);
        return await SaveStateChange(trip, cancellationToken);
    }

    [HttpPost("{id:guid}/restore")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<TripResponse>> Restore(Guid id, CancellationToken cancellationToken)
    {
        var trip = await LoadTripForUpdate(id, cancellationToken);
        if (trip is null)
            return NotFound();
        if (!trip.TryRestore(out var error))
            return StateConflict(error);

        await notifications.QueueTripEventAsync(trip, TripNotificationType.TripReinstated, cancellationToken);
        await inbox.NotifyDriverAsync(trip.DriverId, UserNotificationTypes.TripReinstated, "Trip is back on",
            UserNotificationService.Describe(trip), $"trip-reinstated:{trip.Id}:{DateTimeOffset.UtcNow.UtcTicks}", trip.Id, cancellationToken);
        return await SaveStateChange(trip, cancellationToken);
    }

    [HttpGet("{id:guid}/passengers")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<TripPassengersResponse>> GetPassengers(Guid id, CancellationToken cancellationToken)
    {
        if (!await database.Trips.AnyAsync(item => item.Id == id, cancellationToken))
            return NotFound();

        var rows = await database.TripIntents.AsNoTracking()
            .Where(intent => intent.TripId == id && intent.CancelledAtUtc == null)
            .OrderBy(intent => intent.CreatedAtUtc)
            .Select(intent => new
            {
                intent.PassengerId,
                DropOff = intent.DropOffStop != null ? intent.DropOffStop.Name : null,
                intent.CreatedAtUtc
            })
            .ToListAsync(cancellationToken);
        var ids = rows.Select(row => row.PassengerId).Distinct().ToList();
        var profiles = await database.Passengers.AsNoTracking()
            .Where(passenger => ids.Contains(passenger.Id))
            .ToDictionaryAsync(passenger => passenger.Id, cancellationToken);

        var passengers = rows.Select(row =>
        {
            profiles.TryGetValue(row.PassengerId, out var profile);
            return new TripPassengerResponse(row.PassengerId, profile?.FullName, profile?.Email,
                profile?.Gender, row.DropOff, row.CreatedAtUtc);
        }).ToList();
        return Ok(new TripPassengersResponse(passengers.Count, passengers));
    }

    [HttpDelete("{id:guid}")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<IActionResult> DeleteScheduledTrip(Guid id, CancellationToken cancellationToken)
    {
        var trip = await database.Trips
            .Include(item => item.Intents)
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (trip is null)
            return NotFound();

        if (trip.Status != TripStatus.Scheduled || trip.Intents.Count > 0)
            return Conflict(new ProblemDetails
            {
                Status = StatusCodes.Status409Conflict,
                Title = "This trip cannot be deleted.",
                Detail = "Only scheduled trips without passenger trip intents can be deleted."
            });

        database.Trips.Remove(trip);
        await database.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    private ObjectResult NoPassengerProfile() => StatusCode(StatusCodes.Status403Forbidden, new ProblemDetails
    {
        Status = StatusCodes.Status403Forbidden,
        Title = "No passenger profile.",
        Detail = "This account has no passenger profile, so trips cannot be shown. Ask the university team to add it."
    });

    private IQueryable<Trip> QueryTrips() => database.Trips
        .AsNoTracking()
        .Include(trip => trip.Route)
        .Include(trip => trip.Bus)
        .Include(trip => trip.Driver)
        .Include(trip => trip.Intents);

    private Task<Trip?> LoadTripForUpdate(Guid id, CancellationToken cancellationToken) => database.Trips
        .Include(trip => trip.Route)
        .Include(trip => trip.Bus)
        .Include(trip => trip.Driver)
        .SingleOrDefaultAsync(trip => trip.Id == id, cancellationToken);

    private async Task<ValidationProblemDetails?> ValidateReferences(TripRequest request, CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();

        var route = await database.Routes.AsNoTracking()
            .Include(item => item.RouteStops)
            .SingleOrDefaultAsync(item => item.Id == request.RouteId, cancellationToken);
        if (route is null || !route.IsActive || route.RouteStops.Count == 0)
            errors[nameof(request.RouteId)] = ["Select an existing active route that has at least one stop."];

        if (request.BusId is int busId)
        {
            var bus = await database.Buses.AsNoTracking()
                .SingleOrDefaultAsync(item => item.Id == busId, cancellationToken);
            if (bus is null || !bus.IsActive)
                errors[nameof(request.BusId)] = ["Select an existing active bus or leave the bus unassigned."];
        }

        if (request.DriverId is int driverId)
        {
            var driver = await database.Drivers.AsNoTracking()
                .SingleOrDefaultAsync(item => item.Id == driverId, cancellationToken);
            if (driver is null || !driver.IsActive)
                errors[nameof(request.DriverId)] = ["Select an existing active driver or leave the driver unassigned."];
        }

        return errors.Count == 0 ? null : new ValidationProblemDetails(errors);
    }

    private async Task LoadReferences(Trip trip, CancellationToken cancellationToken)
    {
        trip.Route = await database.Routes.SingleAsync(item => item.Id == trip.RouteId, cancellationToken);
        if (trip.BusId is int busId)
            trip.Bus = await database.Buses.SingleAsync(item => item.Id == busId, cancellationToken);
        if (trip.DriverId is int driverId)
            trip.Driver = await database.Drivers.SingleAsync(item => item.Id == driverId, cancellationToken);
    }

    private BadRequestObjectResult Invalid(string field, string message) =>
        BadRequest(new ValidationProblemDetails(new Dictionary<string, string[]> { [field] = [message] }));

    private bool IsAssignedDriver(Trip trip) =>
        int.TryParse(User.FindFirst(UwayClaimTypes.DriverId)?.Value, out var driverId) &&
        trip.DriverId == driverId;

    private int GetDriverId() => int.Parse(User.FindFirst(UwayClaimTypes.DriverId)!.Value);

    private async Task<ActionResult<TripResponse>> SaveStateChange(Trip trip, CancellationToken cancellationToken)
    {
        try
        {
            await database.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            return StateConflict("Another request changed this trip. Reload it before trying again.");
        }

        return Ok(ToResponse(trip));
    }

    private ConflictObjectResult StateConflict(string? message) => Conflict(new ProblemDetails
    {
        Status = StatusCodes.Status409Conflict,
        Title = "The trip cannot make that state transition.",
        Detail = message
    });

    private static TripResponse ToResponse(Trip trip, bool includeAssignments = true) => new(
        trip.Id,
        trip.RouteId,
        trip.Route.Code,
        trip.Route.Name,
        includeAssignments ? trip.BusId : null,
        includeAssignments ? trip.Bus?.FleetNumber : null,
        includeAssignments ? trip.DriverId : null,
        includeAssignments ? trip.Driver?.FullName : null,
        includeAssignments ? trip.Driver?.PhoneNumber : null,
        trip.DepartureAtUtc,
        trip.Audience,
        trip.Status.ToString(),
        trip.DelayMinutes,
        trip.DelayReason,
        trip.StartedAtUtc,
        trip.EndedAtUtc,
        trip.CancellationReason,
        trip.CancelledAtUtc,
        trip.Version,
        includeAssignments ? trip.Intents.Count(intent => intent.CancelledAtUtc == null) : null);

    public sealed record TripPassengerResponse(
        string PassengerId,
        string? FullName,
        string? Email,
        string? Gender,
        string? DropOffStopName,
        DateTimeOffset JoinedAtUtc);

    public sealed record TripPassengersResponse(int Count, IReadOnlyList<TripPassengerResponse> Passengers);

    public sealed record TripResponse(
        Guid Id,
        int RouteId,
        string RouteCode,
        string RouteName,
        int? BusId,
        string? FleetNumber,
        int? DriverId,
        string? DriverName,
        string? DriverPhone,
        DateTimeOffset DepartureAtUtc,
        string? Audience,
        string Status,
        int DelayMinutes,
        string? DelayReason,
        DateTimeOffset? StartedAtUtc,
        DateTimeOffset? EndedAtUtc,
        string? CancellationReason,
        DateTimeOffset? CancelledAtUtc,
        int Version,
        int? JoinedCount = null);
}
