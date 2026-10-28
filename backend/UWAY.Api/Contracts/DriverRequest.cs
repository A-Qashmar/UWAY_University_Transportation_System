using System.ComponentModel.DataAnnotations;

namespace UWAY.Api.Contracts;

public sealed class DriverRequest
{
    [Required, StringLength(120)]
    public string FullName { get; init; } = string.Empty;

    [Required, StringLength(32, MinimumLength = 6)]
    [RegularExpression(@"^\+?[0-9 ()\-]{6,32}$", ErrorMessage = "Enter a valid phone number.")]
    public string PhoneNumber { get; init; } = string.Empty;

    public bool IsActive { get; init; } = true;

    /// <summary>Optional: the bus this driver normally drives.</summary>
    public int? AssignedBusId { get; init; }
}
