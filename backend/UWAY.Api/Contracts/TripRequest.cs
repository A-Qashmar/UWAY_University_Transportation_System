using System.ComponentModel.DataAnnotations;

namespace UWAY.Api.Contracts;

public sealed class TripRequest
{
    [Range(1, int.MaxValue)]
    public int RouteId { get; init; }

    [Range(1, int.MaxValue)]
    public int? BusId { get; init; }

    [Range(1, int.MaxValue)]
    public int? DriverId { get; init; }

    public DateTimeOffset DepartureAtUtc { get; init; }

    /// <summary>"F" for a women's trip or "M" for a men's trip. Required.</summary>
    [Required]
    [RegularExpression("^[FM]$", ErrorMessage = "Choose F (women) or M (men).")]
    public string? Audience { get; init; }
}
