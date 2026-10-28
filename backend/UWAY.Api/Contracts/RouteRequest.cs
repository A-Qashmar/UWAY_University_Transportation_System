using System.ComponentModel.DataAnnotations;

namespace UWAY.Api.Contracts;

public sealed class RouteRequest
{
    [Required, StringLength(32)]
    public string Code { get; init; } = string.Empty;

    [Required, StringLength(120)]
    public string Name { get; init; } = string.Empty;

    public List<int> StopIds { get; init; } = [];

    public bool IsActive { get; init; } = true;
}
