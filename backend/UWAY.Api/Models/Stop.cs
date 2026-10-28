namespace UWAY.Api.Models;

public sealed class Stop
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }
    public bool IsActive { get; set; } = true;
    public string? SourceGroup { get; set; }
    public string? SourceKey { get; set; }
    /// <summary>"M" for a men-only stop, "F" for a women-only stop, null for everyone.</summary>
    public string? Audience { get; set; }
    public ICollection<RouteStop> RouteStops { get; set; } = new List<RouteStop>();
}
