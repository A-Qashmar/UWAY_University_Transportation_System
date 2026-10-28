namespace UWAY.Api.Models;

/// <summary>
/// An inbox message for one signed-in user (Admin, Driver or Passenger), for example
/// a new report, a report reply, or a driver reporting a delay. Passenger trip
/// events keep using <see cref="TripNotification"/>.
/// </summary>
public sealed class UserNotification
{
    public Guid Id { get; set; }
    public string UserId { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public Guid? TripId { get; set; }
    public string DeduplicationKey { get; set; } = string.Empty;
    public DateTimeOffset CreatedAtUtc { get; set; }
    public DateTimeOffset? ReadAtUtc { get; set; }
}

public static class UserNotificationTypes
{
    public const string ReportReceived = "ReportReceived";
    public const string ReportUpdated = "ReportUpdated";
    public const string TripStarted = "TripStarted";
    public const string TripFinished = "TripFinished";
    public const string TripDelayed = "TripDelayed";
    public const string TripCancelled = "TripCancelled";
    public const string TripReinstated = "TripReinstated";
    public const string TripAssigned = "TripAssigned";
    public const string TripChanged = "TripChanged";
    public const string BusNearlyFull = "BusNearlyFull";
}
