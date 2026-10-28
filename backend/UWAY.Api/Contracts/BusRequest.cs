using System.ComponentModel.DataAnnotations;

namespace UWAY.Api.Contracts;

public sealed class BusRequest
{
    [Required, StringLength(32)]
    public string FleetNumber { get; init; } = string.Empty;

    [Range(1, int.MaxValue)]
    public int Capacity { get; init; }

    public bool IsActive { get; init; } = true;

    /// <summary>Optional: the driver who normally drives this bus.</summary>
    public int? AssignedDriverId { get; init; }
}
