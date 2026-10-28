using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using UWAY.Api.Data;
using UWAY.Api.Models;

namespace UWAY.Api.Services;

public sealed class TripNotificationService(UwayDbContext database)
{
    public const double StopApproachRadiusMeters = 500;

    public async Task QueueTripEventAsync(
        Trip trip,
        TripNotificationType type,
        CancellationToken cancellationToken)
    {
        var (key, title, message) = BuildTripEvent(type, trip);
        var recipients = await database.TripIntents.AsNoTracking()
            .Where(intent => intent.TripId == trip.Id && intent.CancelledAtUtc == null)
            .Select(intent => new { intent.Id })
            .ToListAsync(cancellationToken);

        await AddIfNewAsync(recipients.Select(item => item.Id), key, type, title, message,
            DateTimeOffset.UtcNow, cancellationToken);
    }

    public async Task QueueDropOffApproachAsync(
        Guid tripId,
        int routeId,
        decimal latitude,
        decimal longitude,
        DateTimeOffset occurredAtUtc,
        CancellationToken cancellationToken)
    {
        var selectedStops = await database.RouteStops.AsNoTracking()
            .Where(routeStop => routeStop.RouteId == routeId)
            .Join(database.TripIntents.AsNoTracking().Where(intent =>
                    intent.TripId == tripId && intent.CancelledAtUtc == null && intent.DropOffStopId != null),
                routeStop => routeStop.StopId,
                intent => intent.DropOffStopId!.Value,
                (routeStop, intent) => new
                {
                    IntentId = intent.Id,
                    StopId = routeStop.StopId,
                    StopName = routeStop.Stop.Name,
                    StopLatitude = routeStop.Stop.Latitude,
                    StopLongitude = routeStop.Stop.Longitude
                })
            .Where(item => item.StopLatitude != null && item.StopLongitude != null)
            .ToListAsync(cancellationToken);

        var approaching = selectedStops
            .Where(item => DistanceInMeters(latitude, longitude,
                item.StopLatitude!.Value, item.StopLongitude!.Value) <= StopApproachRadiusMeters)
            .ToList();
        foreach (var group in approaching.GroupBy(item => item.StopId))
        {
            var stopName = group.First().StopName;
            await AddIfNewAsync(group.Select(item => item.IntentId), $"approach-stop:{group.Key}",
                TripNotificationType.BusApproachingDropOff, "Bus approaching your stop",
                FitMessage($"The bus is within {StopApproachRadiusMeters:0} meters of your selected drop-off stop, {stopName}."),
                occurredAtUtc, cancellationToken);
        }
    }

    private async Task AddIfNewAsync(
        IEnumerable<Guid> intentIds,
        string key,
        TripNotificationType type,
        string title,
        string message,
        DateTimeOffset createdAtUtc,
        CancellationToken cancellationToken)
    {
        var ids = intentIds.Distinct().ToArray();
        if (ids.Length == 0)
            return;

        var existingIntentIds = await database.TripNotifications.AsNoTracking()
            .Where(notification => ids.Contains(notification.TripIntentId) &&
                notification.DeduplicationKey == key)
            .Select(notification => notification.TripIntentId)
            .ToListAsync(cancellationToken);
        var existing = existingIntentIds.ToHashSet();

        foreach (var intentId in ids.Where(id => !existing.Contains(id)))
        {
            database.TripNotifications.Add(new TripNotification
            {
                Id = Guid.NewGuid(),
                TripIntentId = intentId,
                Type = type,
                Title = title,
                Message = FitMessage(message),
                DeduplicationKey = key,
                CreatedAtUtc = createdAtUtc.ToUniversalTime()
            });
        }
    }

    private static (string Key, string Title, string Message) BuildTripEvent(
        TripNotificationType type,
        Trip trip) => type switch
    {
        TripNotificationType.TripStarted => ("trip-started", "Trip started", "The bus trip has started."),
        TripNotificationType.TripDelayed =>
            ($"trip-delayed:{Hash($"{trip.DelayMinutes}|{trip.DelayReason}")}", "Trip delayed",
                $"The trip is delayed by {trip.DelayMinutes} minutes. {trip.DelayReason}"),
        TripNotificationType.TripCancelled => ($"trip-cancelled:{trip.CancelledAtUtc?.UtcTicks}", "Trip cancelled",
            FitMessage($"The trip was cancelled. {trip.CancellationReason}")),
        TripNotificationType.TripReinstated => ($"trip-reinstated:{DateTimeOffset.UtcNow.UtcTicks}", "Trip is back on",
            "The cancelled trip is scheduled again. Check its time before you travel."),
        TripNotificationType.TripCompleted => ("trip-completed", "Trip completed", "The bus trip has ended."),
        _ => throw new ArgumentOutOfRangeException(nameof(type), type, "This type is not a trip lifecycle event.")
    };

    private static string Hash(string value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value)));

    private static double DistanceInMeters(decimal latitude1, decimal longitude1, decimal latitude2, decimal longitude2)
    {
        const double earthRadiusMeters = 6_371_000;
        var lat1 = DegreesToRadians((double)latitude1);
        var lat2 = DegreesToRadians((double)latitude2);
        var latitudeDelta = lat2 - lat1;
        var longitudeDelta = DegreesToRadians((double)(longitude2 - longitude1));
        var a = Math.Pow(Math.Sin(latitudeDelta / 2), 2) +
                Math.Cos(lat1) * Math.Cos(lat2) * Math.Pow(Math.Sin(longitudeDelta / 2), 2);
        return earthRadiusMeters * 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
    }

    private static double DegreesToRadians(double degrees) => degrees * Math.PI / 180;

    private static string FitMessage(string message) => message.Length <= 500 ? message : message[..500];
}
