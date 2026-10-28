using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UWAY.Api.Contracts;
using UWAY.Api.Data;
using UWAY.Api.Models;
using UWAY.Api.Services;

namespace UWAY.Api.Controllers;

[ApiController]
[Authorize(Policy = "PassengerOnly")]
[Route("api/trips/{tripId:guid}/intent")]
public sealed class TripIntentsController(UwayDbContext database, PassengerAccess passengerAccess) : ControllerBase
{
    [HttpPost]
    public async Task<ActionResult<TripIntentResponse>> Create(
        Guid tripId,
        CreateTripIntentRequest request,
        CancellationToken cancellationToken)
    {
        var passengerId = GetPassengerId();
        if (passengerId is null)
            return Forbid();

        if (passengerId.Length > 120)
            return Invalid(nameof(passengerId), "The authenticated passenger identifier exceeds 120 characters.");

        var trip = await database.Trips.AsNoTracking()
            .SingleOrDefaultAsync(item => item.Id == tripId, cancellationToken);
        if (trip is null || !await CanSeeTrip(trip, cancellationToken))
            return NotFound();
        if (!CanCreateIntent(trip))
            return StateConflict("You can join a trip that is scheduled or in progress and not cancelled.");

        if (request.DropOffStopId is int dropOffStopId &&
            !await StopBelongsToRoute(trip, dropOffStopId, cancellationToken))
            return Invalid(nameof(request.DropOffStopId), "Select a stop that belongs to this trip's route.");

        var intent = new TripIntent
        {
            Id = Guid.NewGuid(),
            TripId = tripId,
            PassengerId = passengerId,
            DropOffStopId = request.DropOffStopId,
            CreatedAtUtc = DateTimeOffset.UtcNow
        };
        database.TripIntents.Add(intent);

        try
        {
            await database.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception) when (DatabaseErrorResponses.IsUniqueViolation(exception))
        {
            return Conflict(new ProblemDetails
            {
                Status = StatusCodes.Status409Conflict,
                Title = "An active Trip Intent already exists.",
                Detail = "Change the drop-off stop or cancel the existing intent before creating another."
            });
        }
        catch (DbUpdateException exception) when (DatabaseErrorResponses.IsConstraintViolation(exception))
        {
            return DatabaseErrorResponses.ConstraintConflict(this, exception);
        }

        await database.Entry(intent).Reference(item => item.DropOffStop).LoadAsync(cancellationToken);
        return CreatedAtAction(nameof(GetMine), new { tripId }, await ToResponse(intent, cancellationToken));
    }

    [HttpGet]
    public async Task<ActionResult<TripIntentResponse>> GetMine(Guid tripId, CancellationToken cancellationToken)
    {
        var passengerId = GetPassengerId();
        if (passengerId is null)
            return Forbid();

        var intent = await database.TripIntents.AsNoTracking()
            .Include(item => item.DropOffStop)
            .SingleOrDefaultAsync(item => item.TripId == tripId &&
                item.PassengerId == passengerId && item.CancelledAtUtc == null, cancellationToken);
        return intent is null ? NotFound() : Ok(await ToResponse(intent, cancellationToken));
    }

    [HttpPut("drop-off")]
    public async Task<ActionResult<TripIntentResponse>> ChangeDropOff(
        Guid tripId,
        CreateTripIntentRequest request,
        CancellationToken cancellationToken)
    {
        var passengerId = GetPassengerId();
        if (passengerId is null)
            return Forbid();

        var trip = await database.Trips.SingleOrDefaultAsync(item => item.Id == tripId, cancellationToken);
        if (trip is null || !await CanSeeTrip(trip, cancellationToken))
            return NotFound();
        if (!CanChangeDropOff(trip))
            return StateConflict("Drop-off stops can be changed before the trip ends or is cancelled.");

        var intent = await database.TripIntents
            .Include(item => item.DropOffStop)
            .SingleOrDefaultAsync(item => item.TripId == tripId &&
                item.PassengerId == passengerId && item.CancelledAtUtc == null, cancellationToken);
        if (intent is null)
            return NotFound();

        if (request.DropOffStopId is not int newStopId)
            return Invalid(nameof(request.DropOffStopId), "Choose a drop-off stop.");
        if (!await StopBelongsToRoute(trip, newStopId, cancellationToken))
            return Invalid(nameof(request.DropOffStopId), "Select a stop that belongs to this trip's route.");

        intent.DropOffStopId = newStopId;
        await database.SaveChangesAsync(cancellationToken);
        await database.Entry(intent).Reference(item => item.DropOffStop).LoadAsync(cancellationToken);
        return Ok(await ToResponse(intent, cancellationToken));
    }

    [HttpDelete]
    public async Task<ActionResult<CancelTripIntentResponse>> Cancel(Guid tripId, CancellationToken cancellationToken)
    {
        var passengerId = GetPassengerId();
        if (passengerId is null)
            return Forbid();

        var intent = await database.TripIntents.SingleOrDefaultAsync(item => item.TripId == tripId &&
            item.PassengerId == passengerId && item.CancelledAtUtc == null, cancellationToken);
        if (intent is null)
            return NotFound();

        intent.CancelledAtUtc = DateTimeOffset.UtcNow;
        await database.SaveChangesAsync(cancellationToken);
        var expectedRiderCount = await CountActiveIntents(tripId, cancellationToken);
        return Ok(new CancelTripIntentResponse(tripId, intent.CancelledAtUtc.Value, expectedRiderCount));
    }

    private async Task<bool> CanSeeTrip(Trip trip, CancellationToken cancellationToken) =>
        await passengerAccess.GetGenderAsync(User, cancellationToken) is { } gender && trip.Audience == gender;

    private string? GetPassengerId()
    {
        var passengerId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return string.IsNullOrWhiteSpace(passengerId) ? null : passengerId;
    }

    /// <summary>The stop is on the trip's route and not reserved for the other gender.</summary>
    private Task<bool> StopBelongsToRoute(Trip trip, int stopId, CancellationToken cancellationToken) =>
        database.RouteStops.AnyAsync(item => item.RouteId == trip.RouteId && item.StopId == stopId &&
            (item.Stop.Audience == null || item.Stop.Audience == trip.Audience), cancellationToken);

    private Task<int> CountActiveIntents(Guid tripId, CancellationToken cancellationToken) =>
        database.TripIntents.CountAsync(item => item.TripId == tripId && item.CancelledAtUtc == null, cancellationToken);

    private async Task<TripIntentResponse> ToResponse(TripIntent intent, CancellationToken cancellationToken) =>
        new(intent.Id, intent.TripId, intent.DropOffStopId, intent.DropOffStop?.Name,
            intent.CreatedAtUtc, await CountActiveIntents(intent.TripId, cancellationToken));

    private BadRequestObjectResult Invalid(string field, string message) =>
        BadRequest(new ValidationProblemDetails(new Dictionary<string, string[]> { [field] = [message] }));

    private ConflictObjectResult StateConflict(string message) => Conflict(new ProblemDetails
    {
        Status = StatusCodes.Status409Conflict,
        Title = "The Trip Intent operation is not valid for this trip state.",
        Detail = message
    });

    private static bool CanCreateIntent(Trip trip) =>
        trip.Status is TripStatus.Scheduled or TripStatus.Started && trip.CancelledAtUtc == null;

    private static bool CanChangeDropOff(Trip trip) =>
        trip.Status is TripStatus.Scheduled or TripStatus.Started && trip.CancelledAtUtc == null;

    public sealed record TripIntentResponse(
        Guid Id,
        Guid TripId,
        int? DropOffStopId,
        string? DropOffStopName,
        DateTimeOffset CreatedAtUtc,
        int ExpectedRiderCount);

    public sealed record CancelTripIntentResponse(
        Guid TripId,
        DateTimeOffset CancelledAtUtc,
        int ExpectedRiderCount);
}
