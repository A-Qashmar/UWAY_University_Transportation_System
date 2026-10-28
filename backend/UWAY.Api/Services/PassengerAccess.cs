using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using UWAY.Api.Data;

namespace UWAY.Api.Services;

/// <summary>Looks up the signed-in passenger's gender from the database.</summary>
public sealed class PassengerAccess(UwayDbContext database)
{
    /// <summary>"F" or "M", or null when the account has no passenger profile.</summary>
    public async Task<string?> GetGenderAsync(ClaimsPrincipal user, CancellationToken cancellationToken)
    {
        var id = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrWhiteSpace(id))
            return null;
        return await database.Passengers.AsNoTracking()
            .Where(passenger => passenger.Id == id)
            .Select(passenger => passenger.Gender)
            .SingleOrDefaultAsync(cancellationToken);
    }
}
