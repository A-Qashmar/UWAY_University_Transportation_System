using Microsoft.EntityFrameworkCore;
using UWAY.Api.Data;
using UWAY.Api.Models;

namespace UWAY.Api.Services;

/// <summary>
/// Queues inbox messages for users. Messages are added to the context only;
/// the caller saves them together with its own change.
/// </summary>
public sealed class UserNotificationService(UwayDbContext database)
{
    public async Task NotifyAdminsAsync(string type, string title, string message, string key, Guid? tripId, CancellationToken cancellationToken)
    {
        var admins = await database.Users.AsNoTracking()
            .Where(user => user.Role == "Admin" && user.IsActive)
            .Select(user => user.Id)
            .ToListAsync(cancellationToken);
        await AddAsync(admins.Select(id => id.ToString()).ToList(), type, title, message, key, tripId, cancellationToken);
    }

    public async Task NotifyDriverAsync(int? driverId, string type, string title, string message, string key, Guid? tripId, CancellationToken cancellationToken)
    {
        if (driverId is not int id)
            return;
        var users = await database.Users.AsNoTracking()
            .Where(user => user.DriverId == id && user.IsActive)
            .Select(user => user.Id)
            .ToListAsync(cancellationToken);
        await AddAsync(users.Select(id => id.ToString()).ToList(), type, title, message, key, tripId, cancellationToken);
    }

    public Task NotifyUserAsync(string userId, string type, string title, string message, string key, Guid? tripId, CancellationToken cancellationToken) =>
        AddAsync([userId], type, title, message, key, tripId, cancellationToken);

    private async Task AddAsync(IReadOnlyCollection<string> userIds, string type, string title, string message, string key, Guid? tripId, CancellationToken cancellationToken)
    {
        if (userIds.Count == 0)
            return;
        var existing = (await database.UserNotifications.AsNoTracking()
            .Where(item => userIds.Contains(item.UserId) && item.DeduplicationKey == key)
            .Select(item => item.UserId)
            .ToListAsync(cancellationToken)).ToHashSet();
        foreach (var userId in userIds.Where(id => !existing.Contains(id)))
        {
            database.UserNotifications.Add(new UserNotification
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Type = type,
                Title = Fit(title, 120),
                Message = Fit(message, 500),
                TripId = tripId,
                DeduplicationKey = Fit(key, 128),
                CreatedAtUtc = DateTimeOffset.UtcNow
            });
        }
    }

    /// <summary>"Route name · 27 Oct 14:43" (Gulf time) for messages.</summary>
    public static string Describe(Trip trip)
    {
        var name = trip.Route?.Name ?? trip.Route?.Code ?? "Trip";
        var gulf = trip.DepartureAtUtc.ToOffset(TimeSpan.FromHours(4));
        return $"{name} · {gulf:dd MMM HH:mm}";
    }

    private static string Fit(string value, int max) => value.Length <= max ? value : value[..max];
}
