using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using UWAY.Api.Auth;
using UWAY.Api.Data;
using UWAY.Api.Hubs;
using UWAY.Api.Services;

var builder = WebApplication.CreateBuilder(args);
builder.Logging.ClearProviders();
builder.Logging.AddConsole();

builder.Services.AddControllers();
builder.Services.AddSignalR();
builder.Services.AddScoped<TripNotificationService>();
builder.Services.AddScoped<UserNotificationService>();
builder.Services.AddScoped<PassengerAccess>();
builder.Services.AddScoped<SourceStopImporter>();
builder.Services.AddHealthChecks()
    .AddCheck<UwayDatabaseHealthCheck>("database");
builder.Services.AddDbContext<UwayDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("UwayDatabase"))
        // Migrations are hand-written SQL and the snapshot rebuilds the model from code,
        // so this EF warning adds noise. `--migration-status` still reports pending changes.
        .ConfigureWarnings(warnings => warnings.Ignore(RelationalEventId.PendingModelChangesWarning)));
var useDevelopmentHeaderAuthentication = builder.Environment.IsDevelopment() &&
    builder.Configuration.GetValue<bool>("Uway:EnableDevelopmentHeaderAuthentication");
builder.Services.AddSingleton<TokenService>();
var authentication = builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Uway.Smart";
    options.DefaultAuthenticateScheme = "Uway.Smart";
    options.DefaultChallengeScheme = "Uway.Smart";
    options.DefaultForbidScheme = "Uway.Smart";
});
authentication.AddPolicyScheme("Uway.Smart", "Uway", options =>
    options.ForwardDefaultSelector = context =>
        useDevelopmentHeaderAuthentication &&
        !context.Request.Headers.ContainsKey("Authorization") &&
        context.Request.Headers.ContainsKey("X-Uway-Dev-Role")
            ? DevelopmentHeaderAuthenticationHandler.SchemeName
            : BearerAuthenticationHandler.SchemeName);
authentication.AddScheme<AuthenticationSchemeOptions, BearerAuthenticationHandler>(BearerAuthenticationHandler.SchemeName, _ => { });
if (useDevelopmentHeaderAuthentication)
    authentication.AddScheme<AuthenticationSchemeOptions, DevelopmentHeaderAuthenticationHandler>(DevelopmentHeaderAuthenticationHandler.SchemeName, _ => { });
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("PassengerOnly", policy => policy.RequireRole("Passenger"));
    options.AddPolicy("PassengerOrDriver", policy => policy.RequireRole("Passenger", "Driver"));
    options.AddPolicy("PassengerOrAdmin", policy => policy.RequireRole("Passenger", "Admin"));
    options.AddPolicy("DriverOnly", policy => policy.RequireRole("Driver"));
    options.AddPolicy("AdminOnly", policy => policy.RequireRole("Admin"));
    options.AddPolicy("DriverOrAdmin", policy => policy.RequireRole("Driver", "Admin"));
    options.AddPolicy("PassengerDriverOrAdmin", policy => policy.RequireRole("Passenger", "Driver", "Admin"));
    options.AddPolicy("AuthenticatedProjectUser", policy => policy.RequireRole("Passenger", "Driver", "Admin"));
    options.FallbackPolicy = new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build();
});
builder.Services.AddCors(options => options.AddPolicy("LocalClients", policy => policy
    .WithOrigins("http://localhost:5173")
    .AllowAnyHeader()
    .AllowAnyMethod()));

var app = builder.Build();

if (args.Contains("--seed-test-users", StringComparer.OrdinalIgnoreCase))
{
    if (!app.Environment.IsDevelopment())
        throw new InvalidOperationException("Test users can be created only in the Development environment.");

    await using var scope = app.Services.CreateAsyncScope();
    var seeder = new TestUserSeeder(scope.ServiceProvider.GetRequiredService<UwayDbContext>());
    foreach (var line in await seeder.SeedAsync())
        Console.WriteLine(line);
    Console.WriteLine($"Password for every test account: {TestUserSeeder.TestPassword}");
    return;
}

if (args.Contains("--remove-demo-routes", StringComparer.OrdinalIgnoreCase))
{
    if (!app.Environment.IsDevelopment())
        throw new InvalidOperationException("Demo cleanup is available only in the Development environment.");

    await using var scope = app.Services.CreateAsyncScope();
    var cleaner = new DemoDataCleaner(scope.ServiceProvider.GetRequiredService<UwayDbContext>());
    foreach (var line in await cleaner.CleanAsync(args.Contains("--confirm", StringComparer.OrdinalIgnoreCase)))
        Console.WriteLine(line);
    return;
}

if (args.Contains("--seed-source-routes", StringComparer.OrdinalIgnoreCase))
{
    if (!app.Environment.IsDevelopment())
        throw new InvalidOperationException("Route seeding is available only in the Development environment.");

    await using var scope = app.Services.CreateAsyncScope();
    var sourcePath = Path.Combine(AppContext.BaseDirectory, "source-map", "UWAY_stops_coordinates.geojson");
    var seeder = new SourceRouteSeeder(scope.ServiceProvider.GetRequiredService<UwayDbContext>());
    foreach (var line in await seeder.SeedAsync(sourcePath))
        Console.WriteLine(line);
    return;
}

if (args.Contains("--import-source-stops", StringComparer.OrdinalIgnoreCase))
{
    if (!app.Environment.IsDevelopment())
        throw new InvalidOperationException("Source stop import is available only in the Development environment.");

    await using var scope = app.Services.CreateAsyncScope();
    var database = scope.ServiceProvider.GetRequiredService<UwayDbContext>();
    const string requiredMigration = "20261024120000_StopSourceIdentity";
    var appliedMigrations = await database.Database.GetAppliedMigrationsAsync();
    if (!appliedMigrations.Contains(requiredMigration, StringComparer.Ordinal))
        throw new InvalidOperationException($"Apply migration {requiredMigration} before importing source stops.");

    var sourcePath = Path.Combine(AppContext.BaseDirectory, "source-map", "UWAY_stops_coordinates.geojson");
    var result = await scope.ServiceProvider.GetRequiredService<SourceStopImporter>().ImportAsync(sourcePath);
    Console.WriteLine($"Valid source points: {result.ValidFeatureCount}");
    Console.WriteLine($"Added: {result.InsertedCount}");
    Console.WriteLine($"Skipped because already present: {result.SkippedExistingCount} (source key: {result.AlreadyImportedCount}; exact manual match: {result.ExistingManualMatchCount})");
    Console.WriteLine($"Duplicate source entries: {result.DuplicateSourceRecordCount}");
    Console.WriteLine($"Invalid source entries: {result.InvalidFeatureCount}");
    return;
}

if (args.Contains("--migrate", StringComparer.OrdinalIgnoreCase))
{
    await using var scope = app.Services.CreateAsyncScope();
    var database = scope.ServiceProvider.GetRequiredService<UwayDbContext>();
    await database.Database.MigrateAsync();
    return;
}

if (args.Contains("--list-migrations", StringComparer.OrdinalIgnoreCase))
{
    await using var scope = app.Services.CreateAsyncScope();
    var database = scope.ServiceProvider.GetRequiredService<UwayDbContext>();
    foreach (var migration in database.Database.GetMigrations())
        Console.WriteLine(migration);
    return;
}

if (args.Contains("--migration-status", StringComparer.OrdinalIgnoreCase))
{
    await using var scope = app.Services.CreateAsyncScope();
    var database = scope.ServiceProvider.GetRequiredService<UwayDbContext>();
    var applied = (await database.Database.GetAppliedMigrationsAsync()).ToHashSet(StringComparer.Ordinal);
    var known = database.Database.GetMigrations().ToList();
    var pendingModelChanges = database.Database.HasPendingModelChanges();
    var expectedTables = new HashSet<string>(StringComparer.Ordinal)
    {
        "routes", "stops", "route_stops", "buses", "drivers", "trips", "trip_intents", "trip_notifications"
    };
    var expectedTripColumns = new HashSet<string>(StringComparer.Ordinal)
    {
        "DelayReason", "CancellationReason", "CancelledAtUtc", "Version",
        "NearlyFullReportedAtUtc", "NearlyFullReportedByDriverId",
        "CurrentLatitude", "CurrentLongitude", "LocationUpdatedAtUtc"
    };
    var expectedNotificationColumns = new HashSet<string>(StringComparer.Ordinal)
    {
        "TripIntentId", "Type", "Title", "Message", "DeduplicationKey", "CreatedAtUtc", "ReadAtUtc"
    };
    var expectedStopSourceColumns = new HashSet<string>(StringComparer.Ordinal) { "SourceGroup", "SourceKey" };
    var actualTables = new HashSet<string>(StringComparer.Ordinal);
    var actualTripColumns = new HashSet<string>(StringComparer.Ordinal);
    var actualNotificationColumns = new HashSet<string>(StringComparer.Ordinal);
    var actualStopSourceColumns = new HashSet<string>(StringComparer.Ordinal);
    await database.Database.OpenConnectionAsync();
    await using (var command = database.Database.GetDbConnection().CreateCommand())
    {
        command.CommandText = "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name = ANY (ARRAY['routes', 'stops', 'route_stops', 'buses', 'drivers', 'trips', 'trip_intents', 'trip_notifications'])";
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            actualTables.Add(reader.GetString(0));
    }
    await using (var command = database.Database.GetDbConnection().CreateCommand())
    {
        command.CommandText = "SELECT column_name FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'trip_notifications' AND column_name = ANY (ARRAY['TripIntentId', 'Type', 'Title', 'Message', 'DeduplicationKey', 'CreatedAtUtc', 'ReadAtUtc'])";
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            actualNotificationColumns.Add(reader.GetString(0));
    }
    await using (var command = database.Database.GetDbConnection().CreateCommand())
    {
        command.CommandText = "SELECT column_name FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'stops' AND column_name = ANY (ARRAY['SourceGroup', 'SourceKey'])";
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            actualStopSourceColumns.Add(reader.GetString(0));
    }
    await using (var command = database.Database.GetDbConnection().CreateCommand())
    {
        command.CommandText = "SELECT column_name FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'trips' AND column_name = ANY (ARRAY['DelayReason', 'CancellationReason', 'CancelledAtUtc', 'Version', 'NearlyFullReportedAtUtc', 'NearlyFullReportedByDriverId', 'CurrentLatitude', 'CurrentLongitude', 'LocationUpdatedAtUtc'])";
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            actualTripColumns.Add(reader.GetString(0));
    }

    foreach (var migration in known)
        Console.WriteLine($"{(applied.Contains(migration) ? "Applied" : "Pending")}: {migration}");

    foreach (var table in expectedTables.Order())
        Console.WriteLine($"TABLE_{table.ToUpperInvariant()}={(actualTables.Contains(table) ? "Present" : "Missing")}");
    foreach (var column in expectedTripColumns.Order())
        Console.WriteLine($"TRIP_COLUMN_{column.ToUpperInvariant()}={(actualTripColumns.Contains(column) ? "Present" : "Missing")}");
    foreach (var column in expectedNotificationColumns.Order())
        Console.WriteLine($"NOTIFICATION_COLUMN_{column.ToUpperInvariant()}={(actualNotificationColumns.Contains(column) ? "Present" : "Missing")}");
    foreach (var column in expectedStopSourceColumns.Order())
        Console.WriteLine($"STOP_COLUMN_{column.ToUpperInvariant()}={(actualStopSourceColumns.Contains(column) ? "Present" : "Missing")}");

    Console.WriteLine($"PENDING_MIGRATION_COUNT={known.Count(migration => !applied.Contains(migration))}");
    Console.WriteLine($"PENDING_MODEL_CHANGES={pendingModelChanges}");
    Environment.ExitCode = known.Any(migration => !applied.Contains(migration)) || pendingModelChanges ||
        expectedTables.Except(actualTables).Any() || expectedStopSourceColumns.Except(actualStopSourceColumns).Any() || expectedTripColumns.Except(actualTripColumns).Any() ||
        expectedNotificationColumns.Except(actualNotificationColumns).Any() ? 1 : 0;
    return;
}

app.UseCors("LocalClients");
app.UseAuthentication();
app.UseAuthorization();
app.MapHealthChecks("/health").AllowAnonymous();
app.MapControllers();
app.MapHub<TripLocationHub>("/hubs/trip-locations");
app.Run();

public partial class Program { }
