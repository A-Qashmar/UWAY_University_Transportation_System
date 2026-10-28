namespace UWAY.Api.Models;

/// <summary>
/// A person who can sign in. Passengers also have a <see cref="Passenger"/>
/// profile whose Id equals this user's Id; drivers link to a <see cref="Driver"/>.
/// </summary>
public sealed class AppUser
{
    public Guid Id { get; set; }
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public int? DriverId { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTimeOffset CreatedAtUtc { get; set; }
}
