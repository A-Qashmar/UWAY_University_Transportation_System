namespace UWAY.Api.Models;

/// <summary>A passenger report: a lost item, a problem with a trip, or anything else.</summary>
public sealed class Report
{
    public Guid Id { get; set; }
    public string PassengerId { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public Guid? TripId { get; set; }
    public Trip? Trip { get; set; }
    public string Description { get; set; } = string.Empty;
    public string Status { get; set; } = ReportStatuses.Open;
    public string? AdminResponse { get; set; }
    public DateTimeOffset CreatedAtUtc { get; set; }
    public DateTimeOffset UpdatedAtUtc { get; set; }
}

public static class ReportCategories
{
    public const string LostItem = "LostItem";
    public const string TripProblem = "TripProblem";
    public const string DriverOrBus = "DriverOrBus";
    public const string Other = "Other";
    public static readonly string[] All = [LostItem, TripProblem, DriverOrBus, Other];
}

public static class ReportStatuses
{
    public const string Open = "Open";
    public const string InReview = "InReview";
    public const string Resolved = "Resolved";
    public static readonly string[] All = [Open, InReview, Resolved];
}
