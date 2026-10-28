using System.ComponentModel.DataAnnotations;

namespace UWAY.Api.Contracts;

public sealed class CreateTripIntentRequest
{
    [Range(1, int.MaxValue)]
    /// <summary>Optional when joining a trip; required when changing the drop-off stop.</summary>
    public int? DropOffStopId { get; init; }
}
