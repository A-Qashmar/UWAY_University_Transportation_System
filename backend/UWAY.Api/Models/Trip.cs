namespace UWAY.Api.Models;

public sealed class Trip
{
    public Guid Id { get; set; }
    public int RouteId { get; set; }
    /// <summary>"F" for a women's trip, "M" for a men's trip. Null only on trips created before this field existed.</summary>
    public string? Audience { get; set; }
    public Route Route { get; set; } = null!;
    public int? BusId { get; set; }
    public Bus? Bus { get; set; }
    public int? DriverId { get; set; }
    public Driver? Driver { get; set; }
    public DateTimeOffset DepartureAtUtc { get; set; }
    public TripStatus Status { get; set; } = TripStatus.Scheduled;
    public int DelayMinutes { get; set; }
    public string? DelayReason { get; set; }
    public string? CancellationReason { get; set; }
    public DateTimeOffset? CancelledAtUtc { get; set; }
    public DateTimeOffset? StartedAtUtc { get; set; }
    public DateTimeOffset? EndedAtUtc { get; set; }
    public DateTimeOffset? NearlyFullReportedAtUtc { get; set; }
    public int? NearlyFullReportedByDriverId { get; set; }
    public Driver? NearlyFullReportedByDriver { get; set; }
    public decimal? CurrentLatitude { get; set; }
    public decimal? CurrentLongitude { get; set; }
    public DateTimeOffset? LocationUpdatedAtUtc { get; set; }
    public int Version { get; set; } = 1;
    public ICollection<TripIntent> Intents { get; set; } = new List<TripIntent>();

    /// <summary>A delay is a simple alert on the trip, not a status.</summary>
    public bool IsDelayed => DelayMinutes > 0;

    /// <summary>A cancellation is a simple alert on the trip, not a status.</summary>
    public bool IsCancelled => CancelledAtUtc.HasValue;

    public bool TryStart(int driverId, DateTimeOffset startedAtUtc, out string? error)
    {
        if (DriverId != driverId)
        {
            error = "Only the assigned driver can start this trip.";
            return false;
        }

        if (Status != TripStatus.Scheduled || StartedAtUtc.HasValue || CancelledAtUtc.HasValue)
        {
            error = "Only a scheduled, uncancelled trip that has not started can be started.";
            return false;
        }

        StartedAtUtc = startedAtUtc.ToUniversalTime();
        Status = TripStatus.Started;
        Version++;
        error = null;
        return true;
    }

    /// <summary>Admin override: marks a scheduled trip as started without the driver.</summary>
    public bool TryStartAsAdmin(DateTimeOffset startedAtUtc, out string? error)
    {
        if (Status != TripStatus.Scheduled || StartedAtUtc.HasValue || CancelledAtUtc.HasValue)
        {
            error = "Only a scheduled, uncancelled trip that has not started can be started.";
            return false;
        }

        StartedAtUtc = startedAtUtc.ToUniversalTime();
        Status = TripStatus.Started;
        Version++;
        error = null;
        return true;
    }

    /// <summary>Admin override: marks a started trip as finished without the driver.</summary>
    public bool TryEndAsAdmin(DateTimeOffset endedAtUtc, out string? error)
    {
        if (Status != TripStatus.Started || !StartedAtUtc.HasValue || EndedAtUtc.HasValue)
        {
            error = "Only a started trip can be finished.";
            return false;
        }

        EndedAtUtc = endedAtUtc.ToUniversalTime();
        Status = TripStatus.Finished;
        Version++;
        error = null;
        return true;
    }

    public bool TryEnd(int driverId, DateTimeOffset endedAtUtc, out string? error)
    {
        if (DriverId != driverId)
        {
            error = "Only the assigned driver can end this trip.";
            return false;
        }

        if (Status != TripStatus.Started || !StartedAtUtc.HasValue || EndedAtUtc.HasValue)
        {
            error = "Only an active trip can be ended.";
            return false;
        }

        EndedAtUtc = endedAtUtc.ToUniversalTime();
        Status = TripStatus.Finished;
        Version++;
        error = null;
        return true;
    }

    public bool TryDelay(int delayMinutes, string reason, out string? error)
    {
        if (Status != TripStatus.Scheduled || StartedAtUtc.HasValue || CancelledAtUtc.HasValue)
        {
            error = "Only a scheduled, uncancelled trip that has not started can be delayed.";
            return false;
        }

        if (delayMinutes <= 0 || string.IsNullOrWhiteSpace(reason))
        {
            error = "A positive delay and a reason are required.";
            return false;
        }

        DelayMinutes = delayMinutes;
        DelayReason = reason.Trim();
        Version++;
        error = null;
        return true;
    }

    public bool TryCancel(string reason, DateTimeOffset cancelledAtUtc, out string? error)
    {
        if (Status == TripStatus.Finished || CancelledAtUtc.HasValue)
        {
            error = "A finished or already cancelled trip cannot be cancelled.";
            return false;
        }

        if (string.IsNullOrWhiteSpace(reason))
        {
            error = "A cancellation reason is required.";
            return false;
        }

        CancellationReason = reason.Trim();
        CancelledAtUtc = cancelledAtUtc.ToUniversalTime();
        Version++;
        error = null;
        return true;
    }

    /// <summary>Admin override: a cancelled trip becomes a normal scheduled trip again.</summary>
    public bool TryRestore(out string? error)
    {
        if (!CancelledAtUtc.HasValue)
        {
            error = "Only a cancelled trip can be restored.";
            return false;
        }

        if (Status == TripStatus.Finished)
        {
            error = "A finished trip cannot be restored.";
            return false;
        }

        CancelledAtUtc = null;
        CancellationReason = null;
        Version++;
        error = null;
        return true;
    }

    public bool TryReportNearlyFull(int driverId, DateTimeOffset reportedAtUtc, out string? error)
    {
        if (DriverId != driverId)
        {
            error = "Only the assigned driver can report this bus as nearly full.";
            return false;
        }

        if (Status != TripStatus.Started || !StartedAtUtc.HasValue || EndedAtUtc.HasValue)
        {
            error = "A nearly-full report is only valid while the trip is in progress.";
            return false;
        }

        if (!NearlyFullReportedAtUtc.HasValue)
        {
            NearlyFullReportedAtUtc = reportedAtUtc.ToUniversalTime();
            NearlyFullReportedByDriverId = driverId;
            Version++;
        }

        error = null;
        return true;
    }

    public bool TryUpdateLocation(
        int driverId,
        decimal latitude,
        decimal longitude,
        DateTimeOffset receivedAtUtc,
        out string? error)
    {
        if (DriverId != driverId)
        {
            error = "Only the assigned driver can update this trip's location.";
            return false;
        }

        if (Status != TripStatus.Started || !StartedAtUtc.HasValue || EndedAtUtc.HasValue)
        {
            error = "Location updates are only valid while the trip is in progress.";
            return false;
        }

        if (latitude is < -90 or > 90 || longitude is < -180 or > 180)
        {
            error = "Latitude must be between -90 and 90, and longitude between -180 and 180.";
            return false;
        }

        CurrentLatitude = latitude;
        CurrentLongitude = longitude;
        var utcTimestamp = receivedAtUtc.ToUniversalTime();
        LocationUpdatedAtUtc = new DateTimeOffset(
            utcTimestamp.Ticks - utcTimestamp.Ticks % TimeSpan.TicksPerMicrosecond,
            TimeSpan.Zero);
        Version++;
        error = null;
        return true;
    }
}

/// <summary>
/// The primary lifecycle of a trip. Delays and cancellations are alerts carried
/// by <see cref="Trip.DelayMinutes"/> and <see cref="Trip.CancelledAtUtc"/>.
/// </summary>
public enum TripStatus
{
    Scheduled,
    Started,
    Finished
}
