using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using UWAY.Api.Data;
using UWAY.Api.Models;

namespace UWAY.Api.Services;

public sealed class SourceStopImporter(UwayDbContext database)
{
    public async Task<SourceStopImportResult> ImportAsync(string geoJsonPath, CancellationToken cancellationToken = default)
    {
        var sourceFile = await ReadSourceFileAsync(geoJsonPath, cancellationToken);
        var sourceStops = sourceFile.Points;
        var duplicateSourceRecords = sourceFile.DuplicateSourceRecordCount;

        var alreadyImportedKeys = (await database.Stops.AsNoTracking()
                .Where(stop => stop.SourceKey != null)
                .Select(stop => stop.SourceKey!)
                .ToListAsync(cancellationToken))
            .ToHashSet(StringComparer.Ordinal);

        // Do not silently duplicate a manually managed UWAY stop that exactly matches a source point.
        // Such rows are left untouched and can be reconciled by an administrator later.
        var existingManualStops = await database.Stops.AsNoTracking()
            .Where(stop => stop.SourceKey == null)
            .Select(stop => new { stop.Name, stop.Latitude, stop.Longitude })
            .ToListAsync(cancellationToken);

        var additions = new List<Stop>();
        var existingMatchCount = 0;
        var alreadyImportedCount = 0;
        foreach (var sourceStop in sourceStops)
        {
            if (alreadyImportedKeys.Contains(sourceStop.SourceKey))
            {
                alreadyImportedCount++;
                continue;
            }

            var manualMatch = existingManualStops.Any(stop =>
                string.Equals(stop.Name.Trim(), sourceStop.Name, StringComparison.Ordinal) &&
                stop.Latitude == sourceStop.Latitude && stop.Longitude == sourceStop.Longitude);
            if (manualMatch)
            {
                existingMatchCount++;
                continue;
            }

            additions.Add(new Stop
            {
                Name = sourceStop.Name,
                Latitude = sourceStop.Latitude,
                Longitude = sourceStop.Longitude,
                SourceGroup = sourceStop.SourceGroup,
                SourceKey = sourceStop.SourceKey,
                IsActive = true
            });
        }

        database.Stops.AddRange(additions);
        await database.SaveChangesAsync(cancellationToken);
        return new SourceStopImportResult(
            sourceFile.ValidFeatureCount,
            additions.Count,
            alreadyImportedCount,
            existingMatchCount,
            duplicateSourceRecords,
            sourceFile.InvalidFeatureCount);
    }

    public static async Task<SourceStopFileReadResult> ReadSourceFileAsync(
        string geoJsonPath, CancellationToken cancellationToken = default)
    {
        await using var stream = File.OpenRead(geoJsonPath);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
        var root = document.RootElement;
        if (!root.TryGetProperty("type", out var type) || type.GetString() != "FeatureCollection" ||
            !root.TryGetProperty("features", out var features) || features.ValueKind != JsonValueKind.Array)
            throw new InvalidDataException("The source file must be a GeoJSON FeatureCollection.");

        var points = new List<SourceStopInput>();
        var sourceKeys = new HashSet<string>(StringComparer.Ordinal);
        var duplicateCount = 0;
        var validCount = 0;
        var invalidCount = 0;
        foreach (var feature in features.EnumerateArray())
        {
            try
            {
                var point = ParseFeature(feature);
                validCount++;
                if (sourceKeys.Add(point.SourceKey))
                    points.Add(point);
                else
                    duplicateCount++;
            }
            catch (Exception exception) when (exception is InvalidDataException or InvalidOperationException or
                                               JsonException or FormatException or OverflowException)
            {
                invalidCount++;
            }
        }

        return new SourceStopFileReadResult(points, validCount, duplicateCount, invalidCount);
    }

    public static string CreateSourceKey(string sourceGroup, string sourceName, decimal latitude, decimal longitude)
    {
        var canonicalLatitude = decimal.Round(latitude, 6, MidpointRounding.AwayFromZero).ToString("F6", CultureInfo.InvariantCulture);
        var canonicalLongitude = decimal.Round(longitude, 6, MidpointRounding.AwayFromZero).ToString("F6", CultureInfo.InvariantCulture);
        var identity = string.Create(CultureInfo.InvariantCulture,
            $"{sourceGroup.Length}:{sourceGroup}{sourceName.Length}:{sourceName}{canonicalLatitude}{canonicalLongitude}");
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(identity))).ToLowerInvariant();
    }

    private static string RequiredString(JsonElement properties, string propertyName, int maxLength)
    {
        if (!properties.TryGetProperty(propertyName, out var value) || value.ValueKind != JsonValueKind.String)
            throw new InvalidDataException($"A source feature is missing '{propertyName}'.");
        var result = value.GetString()?.Trim();
        if (string.IsNullOrWhiteSpace(result) || result.Length > maxLength)
            throw new InvalidDataException($"'{propertyName}' must contain 1 to {maxLength} characters.");
        return result;
    }

    private static SourceStopInput ParseFeature(JsonElement feature)
    {
        if (!feature.TryGetProperty("geometry", out var geometry) ||
            !geometry.TryGetProperty("type", out var geometryType) || geometryType.GetString() != "Point" ||
            !geometry.TryGetProperty("coordinates", out var coordinates) ||
            coordinates.ValueKind != JsonValueKind.Array || coordinates.GetArrayLength() < 2)
            throw new InvalidDataException("Every imported feature must have Point geometry with [longitude, latitude].");

        var coordinateValues = coordinates.EnumerateArray().Take(2).ToArray();
        if (!coordinateValues[0].TryGetDecimal(out var longitude) || !coordinateValues[1].TryGetDecimal(out var latitude) ||
            latitude is < -90 or > 90 || longitude is < -180 or > 180)
            throw new InvalidDataException("A source point contains invalid longitude/latitude values.");

        if (!feature.TryGetProperty("properties", out var properties))
            throw new InvalidDataException("Every imported feature must include source properties.");
        var sourceGroup = RequiredString(properties, "source_group", 80);
        var sourceName = RequiredString(properties, "source_name", 120);
        latitude = decimal.Round(latitude, 6, MidpointRounding.AwayFromZero);
        longitude = decimal.Round(longitude, 6, MidpointRounding.AwayFromZero);

        return new SourceStopInput(sourceName, sourceGroup, latitude, longitude,
            CreateSourceKey(sourceGroup, sourceName, latitude, longitude));
    }
}

public sealed record SourceStopInput(string Name, string SourceGroup, decimal Latitude, decimal Longitude, string SourceKey);

public sealed record SourceStopFileReadResult(
    IReadOnlyList<SourceStopInput> Points,
    int ValidFeatureCount,
    int DuplicateSourceRecordCount,
    int InvalidFeatureCount);

public sealed record SourceStopImportResult(
    int ValidFeatureCount,
    int InsertedCount,
    int AlreadyImportedCount,
    int ExistingManualMatchCount,
    int DuplicateSourceRecordCount,
    int InvalidFeatureCount)
{
    public int SkippedExistingCount => AlreadyImportedCount + ExistingManualMatchCount;
}
