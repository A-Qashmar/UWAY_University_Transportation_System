namespace UWAY.Api.Models;

public sealed class TripIntent
{
    public Guid Id { get; set; }
    public Guid TripId { get; set; }
    public Trip Trip { get; set; } = null!;
    public string PassengerId { get; set; } = string.Empty;
    public int? DropOffStopId { get; set; }
    public Stop? DropOffStop { get; set; }
    public DateTimeOffset CreatedAtUtc { get; set; }
    public DateTimeOffset? CancelledAtUtc { get; set; }
    public ICollection<TripNotification> Notifications { get; set; } = new List<TripNotification>();
}
