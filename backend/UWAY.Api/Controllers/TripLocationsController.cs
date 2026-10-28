using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using UWAY.Api.Auth;
using UWAY.Api.Contracts;
using UWAY.Api.Data;
using UWAY.Api.Hubs;
using UWAY.Api.Models;
using UWAY.Api.Services;

namespace UWAY.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/trips/{tripId:guid}/location")]
public sealed class TripLocationsController(
    UwayDbContext database,
    IHubContext<TripLocationHub> locationHub,
    PassengerAccess passengerAccess,
    TripNotificationService notifications,
    ILogger<TripLocationsController> logger) : ControllerBase
{
    [HttpPost]
    [Authorize(Policy = "DriverOnly")]
    public async Task<ActionResult<TripLocationResponse>> Update(
        Guid tripId,
        UpdateTripLocationRequest request,
        CancellationToken cancellationToken)
    {
        var trip = await LoadTrip(tripId, cancellationToken);
        if (trip is null)
            return NotFound();
        if (!IsAssignedDriver(trip))
            return Forbid();
        if (trip.Status != TripStatus.Started || !trip.StartedAtUtc.HasValue || trip.EndedAtUtc.HasValue)
            return StateConflict("Location updates are only valid while the trip is in progress.");
        if (trip.Bus is not { IsActive: true })
            return MissingBus();

        if (!trip.TryUpdateLocation(GetDriverId(), request.Latitude, request.Longitude, DateTimeOffset.UtcNow, out var error))
            return InvalidLocation(error);

        await notifications.QueueDropOffApproachAsync(trip.Id, trip.RouteId, request.Latitude,
            request.Longitude, trip.LocationUpdatedAtUtc!.Value, cancellationToken);

        try
        {
            await database.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            return StateConflict("Another request changed this trip. Retry the location update.");
        }

        var location = ToResponse(trip);
        await PublishLocationUpdate(trip, location, cancellationToken);
        return Ok(location);
    }

    [HttpGet]
    [Authorize(Policy = "AuthenticatedProjectUser")]
    public async Task<ActionResult<TripLocationResponse>> GetLatest(Guid tripId, CancellationToken cancellationToken)
    {
        var trip = await LoadTrip(tripId, cancellationToken);
        if (trip is null)
            return NotFound();

        if (User.IsInRole("Driver") && !IsAssignedDriver(trip))
            return Forbid();
        if (User.IsInRole("Passenger") &&
            await passengerAccess.GetGenderAsync(User, cancellationToken) != trip.Audience)
            return NotFound();
        if (trip.Status != TripStatus.Started || !trip.StartedAtUtc.HasValue || trip.EndedAtUtc.HasValue)
            return StateConflict("Live location is available only while the trip is in progress.");
        if (trip.Bus is not { IsActive: true })
            return MissingBus();
        if (trip.CurrentLatitude is null || trip.CurrentLongitude is null || trip.LocationUpdatedAtUtc is null)
            return NoContent();

        return Ok(ToResponse(trip));
    }

    private Task<Trip?> LoadTrip(Guid tripId, CancellationToken cancellationToken) => database.Trips
        .Include(item => item.Bus)
        .SingleOrDefaultAsync(item => item.Id == tripId, cancellationToken);

    private bool IsAssignedDriver(Trip trip) =>
        int.TryParse(User.FindFirst(UwayClaimTypes.DriverId)?.Value, out var driverId) && trip.DriverId == driverId;

    private int GetDriverId() => int.Parse(User.FindFirst(UwayClaimTypes.DriverId)!.Value);

    private async Task PublishLocationUpdate(
        Trip trip,
        TripLocationResponse location,
        CancellationToken cancellationToken)
    {
        var updateIsStillActive = await database.Trips.AsNoTracking().AnyAsync(item =>
            item.Id == trip.Id && item.Status == TripStatus.Started && item.Version == trip.Version,
            cancellationToken);
        if (!updateIsStillActive)
            return;

        try
        {
            await locationHub.Clients
                .Group(TripLocationHub.TripGroup(trip.Id))
                .SendAsync("LocationUpdated", location, cancellationToken);
            await locationHub.Clients
                .Group(TripLocationHub.PassengerTripGroup(trip.Id))
                .SendAsync("LocationUpdated", location, cancellationToken);
        }
        catch (Exception exception)
        {
            logger.LogError(exception, "Could not publish location update for trip {TripId}.", trip.Id);
        }
    }

    private ObjectResult MissingBus() => Conflict(new ProblemDetails
    {
        Status = StatusCodes.Status409Conflict,
        Title = "Live location is not available.",
        Detail = "Assign an active bus to the trip before sending or viewing its location."
    });

    private ConflictObjectResult StateConflict(string detail) => Conflict(new ProblemDetails
    {
        Status = StatusCodes.Status409Conflict,
        Title = "Live location is not available for this trip state.",
        Detail = detail
    });

    private BadRequestObjectResult InvalidLocation(string? detail) => BadRequest(new ProblemDetails
    {
        Status = StatusCodes.Status400BadRequest,
        Title = "The location coordinates are invalid.",
        Detail = detail
    });

    private static TripLocationResponse ToResponse(Trip trip) => new(
        trip.Id,
        trip.CurrentLatitude!.Value,
        trip.CurrentLongitude!.Value,
        trip.LocationUpdatedAtUtc!.Value);

    public sealed record TripLocationResponse(
        Guid TripId,
        decimal Latitude,
        decimal Longitude,
        DateTimeOffset TimestampUtc);
}
