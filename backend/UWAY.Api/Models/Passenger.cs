namespace UWAY.Api.Models;

/// <summary>
/// A passenger profile. <see cref="Id"/> is the identifier the sign-in
/// provides (the NameIdentifier claim). Gender decides which trips the
/// passenger can see: "F" for women's trips, "M" for men's trips.
/// </summary>
public sealed class Passenger
{
    public string Id { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string Gender { get; set; } = string.Empty;
}

public static class TripAudiences
{
    public const string Women = "F";
    public const string Men = "M";
    public static bool IsValid(string? value) => value is Women or Men;
}
