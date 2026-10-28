using Microsoft.EntityFrameworkCore;
using UWAY.Api.Data;

namespace UWAY.Api.Services;

/// <summary>
/// Removes routes that are not official (anything not seeded from the source map) together with
/// their trips. Buses, drivers, stops and accounts are never touched.
/// </summary>
public sealed class DemoDataCleaner(UwayDbContext database)
{
    public async Task<IReadOnlyList<string>> CleanAsync(bool apply, CancellationToken cancellationToken = default)
    {
        var log = new List<string>();
        var official = SourceRouteSeeder.OfficialCodes;
        var routes = await database.Routes
            .Where(route => !official.Contains(route.Code))
            .ToListAsync(cancellationToken);
        if (routes.Count == 0)
        {
            log.Add("No unofficial routes found. Nothing to remove.");
            return log;
        }

        var routeIds = routes.Select(route => route.Id).ToList();
        var trips = await database.Trips.Where(trip => routeIds.Contains(trip.RouteId)).ToListAsync(cancellationToken);
        var tripIds = trips.Select(trip => trip.Id).ToList();
        // Trips created before audiences existed cannot be shown to any passenger.
        var orphanTrips = await database.Trips
            .Where(trip => trip.Audience == null && !routeIds.Contains(trip.RouteId))
            .ToListAsync(cancellationToken);
        trips.AddRange(orphanTrips);
        tripIds.AddRange(orphanTrips.Select(trip => trip.Id));

        foreach (var route in routes)
            log.Add($"Route {route.Code}: '{route.Name}' ({trips.Count(trip => trip.RouteId == route.Id)} trips)");
        if (orphanTrips.Count > 0)
            log.Add($"Trips on official routes without an audience (legacy): {orphanTrips.Count}");

        if (!apply)
        {
            log.Add("Dry run only. Add --confirm to delete the items above.");
            return log;
        }

        var notifications = await database.UserNotifications
            .Where(notification => notification.TripId != null && tripIds.Contains(notification.TripId.Value))
            .ToListAsync(cancellationToken);
        database.UserNotifications.RemoveRange(notifications);
        database.Trips.RemoveRange(trips); // intents and their notifications cascade; reports keep a null trip
        await database.SaveChangesAsync(cancellationToken);
        database.Routes.RemoveRange(routes); // route stops cascade
        await database.SaveChangesAsync(cancellationToken);
        log.Add($"Deleted {routes.Count} routes, {trips.Count} trips, {notifications.Count} notifications.");
        return log;
    }
}
