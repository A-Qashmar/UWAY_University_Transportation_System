using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UWAY.Api.Auth;
using UWAY.Api.Data;
using UWAY.Api.Models;
using UWAY.Api.Services;

namespace UWAY.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/trips/{tripId:guid}")]
public sealed class TripCapacityController(UwayDbContext database, UserNotificationService inbox) : ControllerBase
{
    [HttpGet("capacity")]
    [Authorize(Policy = "DriverOrAdmin")]
    public async Task<ActionResult<TripCapacityResponse>> GetCapacity(Guid tripId, CancellationToken cancellationToken)
    {
        var trip = await LoadTrip(tripId, cancellationToken);
        if (trip is null)
            return NotFound();
        if (!CanMonitorCapacity(trip.Status))
            return StateConflict("Capacity is monitored only while a trip is scheduled, delayed, or in progress.");
        if (User.IsInRole("Driver") && !IsAssignedDriver(trip))
            return Forbid();
        if (trip.Bus is not { IsActive: true })
            return MissingBus();

        return Ok(await ToResponse(trip, cancellationToken));
    }

    [HttpPost("nearly-full")]
    [Authorize(Policy = "DriverOnly")]
    public async Task<ActionResult<TripCapacityResponse>> ReportNearlyFull(Guid tripId, CancellationToken cancellationToken)
    {
        var trip = await LoadTrip(tripId, cancellationToken);
        if (trip is null)
            return NotFound();
        if (!IsAssignedDriver(trip))
            return Forbid();
        if (trip.Status != TripStatus.Started)
            return StateConflict("A nearly-full report is only valid while the assigned driver's trip is in progress.");
        if (trip.Bus is not { IsActive: true })
            return MissingBus();

        if (!trip.TryReportNearlyFull(GetDriverId(), DateTimeOffset.UtcNow, out var error))
            return StateConflict(error ?? "The nearly-full report is not valid for this trip.");

        await inbox.NotifyAdminsAsync(UserNotificationTypes.BusNearlyFull, "Bus is nearly full",
            $"{UserNotificationService.Describe(trip)}: the driver reports the bus is nearly full.",
            $"nearly-full:{trip.Id}:{trip.NearlyFullReportedAtUtc?.UtcTicks}", trip.Id, cancellationToken);
        try
        {
            await database.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            return StateConflict("Another request changed this trip. Reload it before trying again.");
        }

        await database.Entry(trip)
            .Reference(item => item.NearlyFullReportedByDriver)
            .LoadAsync(cancellationToken);
        return Ok(await ToResponse(trip, cancellationToken));
    }

    private Task<Trip?> LoadTrip(Guid tripId, CancellationToken cancellationToken) => database.Trips
        .Include(item => item.Bus)
        .Include(item => item.Route)
        .Include(item => item.NearlyFullReportedByDriver)
        .SingleOrDefaultAsync(item => item.Id == tripId, cancellationToken);

    private Task<int> CountExpectedRiders(Guid tripId, CancellationToken cancellationToken) =>
        database.TripIntents.CountAsync(item => item.TripId == tripId && item.CancelledAtUtc == null, cancellationToken);

    private async Task<TripCapacityResponse> ToResponse(Trip trip, CancellationToken cancellationToken)
    {
        var expectedRiderCount = await CountExpectedRiders(trip.Id, cancellationToken);
        var capacityStatus = TripCapacityRules.Determine(
            expectedRiderCount,
            trip.Bus!.Capacity,
            trip.NearlyFullReportedAtUtc.HasValue);

        return new TripCapacityResponse(
            trip.Id,
            trip.Status.ToString(),
            expectedRiderCount,
            trip.BusId!.Value,
            trip.Bus.FleetNumber,
            trip.Bus.Capacity,
            capacityStatus.ToString(),
            TripCapacityRules.NearlyFullThresholdPercent,
            trip.NearlyFullReportedAtUtc,
            trip.NearlyFullReportedByDriverId,
            trip.NearlyFullReportedByDriver?.FullName);
    }

    private bool IsAssignedDriver(Trip trip) =>
        int.TryParse(User.FindFirst(UwayClaimTypes.DriverId)?.Value, out var driverId) && trip.DriverId == driverId;

    private int GetDriverId() => int.Parse(User.FindFirst(UwayClaimTypes.DriverId)!.Value);

    private ObjectResult MissingBus() => Conflict(new ProblemDetails
    {
        Status = StatusCodes.Status409Conflict,
        Title = "Capacity cannot be determined.",
        Detail = "Assign an active bus to the trip before monitoring or reporting capacity."
    });

    private ConflictObjectResult StateConflict(string? detail) => Conflict(new ProblemDetails
    {
        Status = StatusCodes.Status409Conflict,
        Title = "Capacity operation is not valid for this trip state.",
        Detail = detail
    });

    private static bool CanMonitorCapacity(TripStatus status) =>
        status is TripStatus.Scheduled or TripStatus.Started;

    public sealed record TripCapacityResponse(
        Guid TripId,
        string TripStatus,
        int ExpectedRiderCount,
        int BusId,
        string FleetNumber,
        int BusCapacity,
        string CapacityStatus,
        int NearlyFullThresholdPercent,
        DateTimeOffset? DriverNearlyFullReportedAtUtc,
        int? DriverNearlyFullReportedByDriverId,
        string? DriverNearlyFullReportedByDriverName);
}
