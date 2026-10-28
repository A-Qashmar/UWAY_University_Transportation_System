using Microsoft.EntityFrameworkCore;
using UWAY.Api.Auth;
using UWAY.Api.Data;
using UWAY.Api.Models;

namespace UWAY.Api.Services;

/// <summary>Creates the pre-made test accounts for local development.</summary>
public sealed class TestUserSeeder(UwayDbContext database)
{
    public const string TestPassword = "Uway@2026";

    public async Task<IReadOnlyList<string>> SeedAsync(CancellationToken cancellationToken = default)
    {
        var lines = new List<string>();
        var accounts = new List<(string Email, string Name, string Role, string? Gender, int? DriverId)>
        {
            ("admin@uway.test", "UWAY Administrator", "Admin", null, null),
            ("omar.hassan@uway.test", "Omar Hassan", "Passenger", "M", null),
            ("khalid.saeed@uway.test", "Khalid Saeed", "Passenger", "M", null),
            ("mariam.ali@uway.test", "Mariam Ali", "Passenger", "F", null),
            ("noura.salem@uway.test", "Noura Salem", "Passenger", "F", null),
        };
        foreach (var driver in await database.Drivers.AsNoTracking().Where(item => item.IsActive).OrderBy(item => item.Id).ToListAsync(cancellationToken))
            accounts.Add(($"driver{driver.Id}@uway.test", driver.FullName, "Driver", null, driver.Id));

        foreach (var (email, name, role, gender, driverId) in accounts)
        {
            var user = await database.Users.SingleOrDefaultAsync(item => item.Email == email, cancellationToken);
            if (user is null)
            {
                user = new AppUser { Id = Guid.NewGuid(), Email = email, CreatedAtUtc = DateTimeOffset.UtcNow };
                database.Users.Add(user);
            }
            user.FullName = name;
            user.Role = role;
            user.DriverId = driverId;
            user.IsActive = true;
            user.PasswordHash = UwayPasswordHasher.Hash(TestPassword);

            if (gender is not null)
            {
                var passengerId = user.Id.ToString();
                var profile = await database.Passengers.SingleOrDefaultAsync(item => item.Id == passengerId, cancellationToken);
                if (profile is null)
                    database.Passengers.Add(profile = new Passenger { Id = passengerId });
                profile.Email = email;
                profile.FullName = name;
                profile.Gender = gender;
            }
            lines.Add($"{role,-9} {email,-28} {name}{(gender is null ? "" : $" ({gender})")}");
        }
        await database.SaveChangesAsync(cancellationToken);
        return lines;
    }
}
