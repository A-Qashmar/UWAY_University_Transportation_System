namespace UWAY.Api.Models;

public sealed class TripNotification
{
    public Guid Id { get; set; }
    public Guid TripIntentId { get; set; }
    public TripIntent TripIntent { get; set; } = null!;
    public TripNotificationType Type { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public string DeduplicationKey { get; set; } = string.Empty;
    public DateTimeOffset CreatedAtUtc { get; set; }
    public DateTimeOffset? ReadAtUtc { get; set; }
}

public enum TripNotificationType
{
    TripStarted,
    TripDelayed,
    TripCancelled,
    TripCompleted,
    BusApproachingDropOff,
    TripReinstated
}
