using System.ComponentModel.DataAnnotations;

namespace UWAY.Api.Contracts;

public sealed class CancelTripRequest
{
    [Required, StringLength(500)]
    public string Reason { get; init; } = string.Empty;
}
