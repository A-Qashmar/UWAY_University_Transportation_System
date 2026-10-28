using System.ComponentModel.DataAnnotations;

namespace UWAY.Api.Contracts;

public sealed class DelayTripRequest
{
    [Range(1, int.MaxValue)]
    public int DelayMinutes { get; init; }

    [Required, StringLength(500)]
    public string Reason { get; init; } = string.Empty;
}
