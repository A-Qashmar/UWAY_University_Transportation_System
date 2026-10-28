using Microsoft.EntityFrameworkCore;
using UWAY.Api.Data;
using UWAY.Api.Models;
using BusRoute = UWAY.Api.Models.Route;

namespace UWAY.Api.Services;

/// <summary>
/// Creates the real university lines from the imported source stops: for each
/// line a morning route (gathering points, then the four UOS campus points)
/// and a return route (first campus point, then the gathering points in
/// reverse). Existing route codes are left alone, so it is safe to run twice.
/// Stops must already be imported with --import-source-stops.
/// </summary>
public sealed class SourceRouteSeeder(UwayDbContext database)
{
    private sealed record Line(string GroupPrefix, string InCode, string OutCode, string Place);

    private static readonly Line[] Lines =
    [
        new("King Faisal Route", "KF-IN", "KF-OUT", "King Faisal Line"),
        new("Al Heerah Route", "HRH-IN", "HRH-OUT", "Al Heera Line")
    ];

    /// <summary>Codes of the official routes; every other route is a demo/unofficial one.</summary>
    public static IReadOnlyCollection<string> OfficialCodes { get; } =
        [.. Lines.SelectMany(line => new[] { line.InCode, line.OutCode })];

    public async Task<IReadOnlyList<string>> SeedAsync(string geoJsonPath, CancellationToken cancellationToken = default)
    {
        var log = new List<string>();
        var source = await SourceStopImporter.ReadSourceFileAsync(geoJsonPath, cancellationToken);
        var stopsByKey = await database.Stops
            .Where(stop => stop.SourceKey != null)
            .ToDictionaryAsync(stop => stop.SourceKey!, cancellationToken);
        var existingRoutes = (await database.Routes.Include(route => route.RouteStops).ToListAsync(cancellationToken))
            .ToDictionary(route => route.Code, StringComparer.Ordinal);

        var campus = source.Points
            .Where(point => point.SourceGroup.Contains("Returning Points", StringComparison.Ordinal) &&
                            point.Name.StartsWith("UOS - ", StringComparison.Ordinal))
            .Select(point => stopsByKey.GetValueOrDefault(point.SourceKey))
            .Where(stop => stop is not null)
            .Select(stop => stop!)
            .ToList();
        // UOS - M3 is for men and UOS - W3 for women; a trip only uses its own.
        foreach (var stop in campus)
        {
            var audience = stop.Name switch { "UOS - M3" => "M", "UOS - W3" => "F", _ => stop.Audience };
            if (stop.Audience != audience)
                stop.Audience = audience;
        }
        if (campus.Count == 0)
        {
            log.Add("No UOS campus stops found. Run --import-source-stops first.");
            return log;
        }

        foreach (var line in Lines)
        {
            // The file lists each group's stops in their source order.
            var gathering = source.Points
                .Where(point => point.SourceGroup.StartsWith(line.GroupPrefix, StringComparison.Ordinal))
                .Select(point => stopsByKey.GetValueOrDefault(point.SourceKey))
                .Where(stop => stop is not null)
                .Select(stop => stop!)
                .ToList();
            if (gathering.Count == 0)
            {
                log.Add($"{line.Place}: no imported stops found, skipped.");
                continue;
            }

            await AddAsync(line.InCode, $"{line.Place} → University City", [.. gathering, .. campus], log, existingRoutes, cancellationToken);
            await AddAsync(line.OutCode, $"University City → {line.Place}",
                [.. campus.Where(stop => stop.Audience is not null), .. Enumerable.Reverse(gathering)], log, existingRoutes, cancellationToken);
        }

        await database.SaveChangesAsync(cancellationToken);
        return log;
    }

    private async Task AddAsync(string code, string name, IReadOnlyList<Stop> stops, List<string> log, Dictionary<string, BusRoute> existingRoutes, CancellationToken cancellationToken)
    {
        if (existingRoutes.TryGetValue(code, out var existing))
        {
            if (existing.Name != name)
            {
                existing.Name = name;
                log.Add($"{code}: already exists, renamed to '{name}'.");
            }
            // Official routes follow the source: bring the stop list up to date.
            var current = existing.RouteStops.OrderBy(item => item.StopOrder).Select(item => item.StopId).ToList();
            if (!current.SequenceEqual(stops.Select(stop => stop.Id)))
            {
                // Replaced in one go: the (route, order) pairs would clash if edited one by one.
                await database.SaveChangesAsync(cancellationToken);
                await database.RouteStops.Where(item => item.RouteId == existing.Id).ExecuteDeleteAsync(cancellationToken);
                foreach (var entry in database.ChangeTracker.Entries<RouteStop>().Where(entry => entry.Entity.RouteId == existing.Id).ToList())
                    entry.State = EntityState.Detached;
                for (var index = 0; index < stops.Count; index++)
                    database.RouteStops.Add(new RouteStop { RouteId = existing.Id, StopId = stops[index].Id, StopOrder = index + 1 });
                log.Add($"{code}: stop list updated ({stops.Count} stops).");
            }
            else
                log.Add($"{code}: already up to date.");
            return;
        }

        var route = new BusRoute { Code = code, Name = name, IsActive = true };
        for (var index = 0; index < stops.Count; index++)
            route.RouteStops.Add(new RouteStop { Stop = stops[index], StopOrder = index + 1 });
        database.Routes.Add(route);
        existingRoutes[code] = route;
        log.Add($"{code}: created '{name}' with {stops.Count} stops.");
    }
}
