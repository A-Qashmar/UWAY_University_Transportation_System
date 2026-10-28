using System.ComponentModel.DataAnnotations;

namespace UWAY.Api.Contracts;

public sealed class StopRequest
{
    [Required, StringLength(120)]
    public string Name { get; init; } = string.Empty;

    [Range(typeof(decimal), "-90", "90")]
    public decimal? Latitude { get; init; }

    [Range(typeof(decimal), "-180", "180")]
    public decimal? Longitude { get; init; }

    public bool IsActive { get; init; } = true;

    /// <summary>"M" (men only), "F" (women only) or empty (everyone).</summary>
    [RegularExpression("^[MF]$", ErrorMessage = "Audience must be M, F or empty.")]
    public string? Audience { get; init; }
}
