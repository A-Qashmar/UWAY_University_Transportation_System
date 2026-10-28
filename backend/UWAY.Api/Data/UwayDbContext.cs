using Microsoft.EntityFrameworkCore;
using Npgsql.EntityFrameworkCore.PostgreSQL;
using UWAY.Api.Models;
using BusRoute = UWAY.Api.Models.Route;

namespace UWAY.Api.Data;

public sealed class UwayDbContext(DbContextOptions<UwayDbContext> options) : DbContext(options)
{
    public DbSet<BusRoute> Routes => Set<BusRoute>();
    public DbSet<Stop> Stops => Set<Stop>();
    public DbSet<RouteStop> RouteStops => Set<RouteStop>();
    public DbSet<Bus> Buses => Set<Bus>();
    public DbSet<Driver> Drivers => Set<Driver>();
    public DbSet<Trip> Trips => Set<Trip>();
    public DbSet<Passenger> Passengers => Set<Passenger>();
    public DbSet<Report> Reports => Set<Report>();
    public DbSet<AppUser> Users => Set<AppUser>();
    public DbSet<UserNotification> UserNotifications => Set<UserNotification>();
    public DbSet<ReportAttachment> ReportAttachments => Set<ReportAttachment>();
    public DbSet<TripIntent> TripIntents => Set<TripIntent>();
    public DbSet<TripNotification> TripNotifications => Set<TripNotification>();

    protected override void OnModelCreating(ModelBuilder modelBuilder) => ConfigureModel(modelBuilder);

    public static void ConfigureModel(ModelBuilder modelBuilder)
    {
        modelBuilder.UseIdentityByDefaultColumns();
        modelBuilder.HasAnnotation("Relational:MaxIdentifierLength", 63);

        modelBuilder.Entity<BusRoute>(entity =>
        {
            entity.ToTable("routes");
            entity.HasKey(route => route.Id);
            entity.Property(route => route.Id).ValueGeneratedOnAdd().HasColumnType("integer");
            entity.Property(route => route.Code).HasMaxLength(32).IsRequired().HasColumnType("character varying(32)");
            entity.Property(route => route.Name).HasMaxLength(120).IsRequired().HasColumnType("character varying(120)");
            entity.Property(route => route.IsActive).HasColumnType("boolean");
            entity.HasIndex(route => route.Code).IsUnique();
        });

        modelBuilder.Entity<Stop>(entity =>
        {
            entity.ToTable("stops", table =>
            {
                table.HasCheckConstraint("CK_stops_coordinate_pair", "(\"Latitude\" IS NULL AND \"Longitude\" IS NULL) OR (\"Latitude\" IS NOT NULL AND \"Longitude\" IS NOT NULL)");
                table.HasCheckConstraint("CK_stops_latitude", "\"Latitude\" IS NULL OR \"Latitude\" BETWEEN -90 AND 90");
                table.HasCheckConstraint("CK_stops_longitude", "\"Longitude\" IS NULL OR \"Longitude\" BETWEEN -180 AND 180");
            });
            entity.HasKey(stop => stop.Id);
            entity.Property(stop => stop.Id).ValueGeneratedOnAdd().HasColumnType("integer");
            entity.Property(stop => stop.Name).HasMaxLength(120).IsRequired().HasColumnType("character varying(120)");
            entity.Property(stop => stop.Latitude).HasPrecision(9, 6).HasColumnType("numeric(9,6)");
            entity.Property(stop => stop.Longitude).HasPrecision(9, 6).HasColumnType("numeric(9,6)");
            entity.Property(stop => stop.IsActive).HasColumnType("boolean");
            entity.Property(stop => stop.SourceGroup).HasMaxLength(80).HasColumnType("character varying(80)");
            entity.Property(stop => stop.SourceKey).HasMaxLength(64).HasColumnType("character varying(64)");
            entity.Property(stop => stop.Audience).HasMaxLength(1).HasColumnType("character varying(1)");
            entity.HasIndex(stop => stop.SourceKey).IsUnique();
        });

        modelBuilder.Entity<RouteStop>(entity =>
        {
            entity.ToTable("route_stops", table =>
                table.HasCheckConstraint("CK_route_stops_order", "\"StopOrder\" > 0"));
            entity.HasKey(routeStop => new { routeStop.RouteId, routeStop.StopId });
            entity.Property(routeStop => routeStop.RouteId).HasColumnType("integer");
            entity.Property(routeStop => routeStop.StopId).HasColumnType("integer");
            entity.Property(routeStop => routeStop.StopOrder).HasColumnType("integer");
            entity.HasIndex(routeStop => new { routeStop.RouteId, routeStop.StopOrder }).IsUnique();
            entity.HasIndex(routeStop => routeStop.StopId);
            entity.HasOne(routeStop => routeStop.Route)
                .WithMany(route => route.RouteStops)
                .HasForeignKey(routeStop => routeStop.RouteId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(routeStop => routeStop.Stop)
                .WithMany(stop => stop.RouteStops)
                .HasForeignKey(routeStop => routeStop.StopId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Bus>(entity =>
        {
            entity.ToTable("buses", table =>
                table.HasCheckConstraint("CK_buses_capacity", "\"Capacity\" > 0"));
            entity.HasKey(bus => bus.Id);
            entity.Property(bus => bus.Id).ValueGeneratedOnAdd().HasColumnType("integer");
            entity.Property(bus => bus.FleetNumber).HasMaxLength(32).IsRequired().HasColumnType("character varying(32)");
            entity.Property(bus => bus.Capacity).HasColumnType("integer");
            entity.Property(bus => bus.IsActive).HasColumnType("boolean");
            entity.HasIndex(bus => bus.FleetNumber).IsUnique();
        });

        modelBuilder.Entity<Driver>(entity =>
        {
            entity.ToTable("drivers");
            entity.HasKey(driver => driver.Id);
            entity.Property(driver => driver.Id).ValueGeneratedOnAdd().HasColumnType("integer");
            entity.Property(driver => driver.FullName).HasMaxLength(120).IsRequired().HasColumnType("character varying(120)");
            entity.Property(driver => driver.PhoneNumber).HasMaxLength(32).HasColumnType("character varying(32)");
            entity.Property(driver => driver.IsActive).HasColumnType("boolean");
            entity.Property(driver => driver.AssignedBusId).HasColumnType("integer");
            entity.HasIndex(driver => driver.AssignedBusId).IsUnique();
            entity.HasOne<Bus>().WithMany().HasForeignKey(driver => driver.AssignedBusId).OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<Report>(entity =>
        {
            entity.ToTable("reports", table =>
            {
                table.HasCheckConstraint("CK_reports_category", "\"Category\" IN ('LostItem', 'TripProblem', 'DriverOrBus', 'Other')");
                table.HasCheckConstraint("CK_reports_status", "\"Status\" IN ('Open', 'InReview', 'Resolved')");
            });
            entity.HasKey(report => report.Id);
            entity.Property(report => report.Id).ValueGeneratedOnAdd().HasColumnType("uuid");
            entity.Property(report => report.PassengerId).HasMaxLength(120).IsRequired().HasColumnType("character varying(120)");
            entity.Property(report => report.Category).HasMaxLength(24).IsRequired().HasColumnType("character varying(24)");
            entity.Property(report => report.TripId).HasColumnType("uuid");
            entity.Property(report => report.Description).HasMaxLength(1000).IsRequired().HasColumnType("character varying(1000)");
            entity.Property(report => report.Status).HasMaxLength(16).IsRequired().HasColumnType("character varying(16)");
            entity.Property(report => report.AdminResponse).HasMaxLength(1000).HasColumnType("character varying(1000)");
            entity.Property(report => report.CreatedAtUtc).HasColumnType("timestamp with time zone");
            entity.Property(report => report.UpdatedAtUtc).HasColumnType("timestamp with time zone");
            entity.HasIndex(report => new { report.PassengerId, report.CreatedAtUtc });
            entity.HasOne(report => report.Trip)
                .WithMany()
                .HasForeignKey(report => report.TripId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<ReportAttachment>(entity =>
        {
            entity.ToTable("report_attachments");
            entity.HasKey(item => item.Id);
            entity.Property(item => item.Id).ValueGeneratedNever().HasColumnType("uuid");
            entity.Property(item => item.FileName).HasMaxLength(200).IsRequired().HasColumnType("character varying(200)");
            entity.Property(item => item.ContentType).HasMaxLength(100).IsRequired().HasColumnType("character varying(100)");
            entity.Property(item => item.SizeBytes).HasColumnType("bigint");
            entity.Property(item => item.Data).IsRequired().HasColumnType("bytea");
            entity.Property(item => item.CreatedAtUtc).HasColumnType("timestamp with time zone");
            entity.HasIndex(item => item.ReportId);
            entity.HasOne(item => item.Report).WithMany().HasForeignKey(item => item.ReportId).OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<UserNotification>(entity =>
        {
            entity.ToTable("user_notifications");
            entity.HasKey(item => item.Id);
            entity.Property(item => item.Id).ValueGeneratedNever().HasColumnType("uuid");
            entity.Property(item => item.UserId).HasMaxLength(120).IsRequired().HasColumnType("character varying(120)");
            entity.Property(item => item.Type).HasMaxLength(40).IsRequired().HasColumnType("character varying(40)");
            entity.Property(item => item.Title).HasMaxLength(120).IsRequired().HasColumnType("character varying(120)");
            entity.Property(item => item.Message).HasMaxLength(500).IsRequired().HasColumnType("character varying(500)");
            entity.Property(item => item.TripId).HasColumnType("uuid");
            entity.Property(item => item.DeduplicationKey).HasMaxLength(128).IsRequired().HasColumnType("character varying(128)");
            entity.Property(item => item.CreatedAtUtc).HasColumnType("timestamp with time zone");
            entity.Property(item => item.ReadAtUtc).HasColumnType("timestamp with time zone");
            entity.HasIndex(item => new { item.UserId, item.DeduplicationKey }).IsUnique();
            entity.HasIndex(item => new { item.UserId, item.CreatedAtUtc });
        });

        modelBuilder.Entity<AppUser>(entity =>
        {
            entity.ToTable("users", table =>
            {
                table.HasCheckConstraint("CK_users_role", "\"Role\" IN ('Passenger', 'Driver', 'Admin')");
                table.HasCheckConstraint("CK_users_email_lower", "\"Email\" = lower(\"Email\")");
            });
            entity.HasKey(user => user.Id);
            entity.Property(user => user.Id).ValueGeneratedNever().HasColumnType("uuid");
            entity.Property(user => user.Email).HasMaxLength(200).IsRequired().HasColumnType("character varying(200)");
            entity.Property(user => user.PasswordHash).HasMaxLength(300).IsRequired().HasColumnType("character varying(300)");
            entity.Property(user => user.Role).HasMaxLength(16).IsRequired().HasColumnType("character varying(16)");
            entity.Property(user => user.FullName).HasMaxLength(200).IsRequired().HasColumnType("character varying(200)");
            entity.Property(user => user.DriverId).HasColumnType("integer");
            entity.Property(user => user.IsActive).HasColumnType("boolean");
            entity.Property(user => user.CreatedAtUtc).HasColumnType("timestamp with time zone");
            entity.HasIndex(user => user.Email).IsUnique();
            entity.HasOne<Driver>().WithMany().HasForeignKey(user => user.DriverId).OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<Passenger>(entity =>
        {
            entity.ToTable("passengers", table =>
                table.HasCheckConstraint("CK_passengers_gender", "\"Gender\" IN ('F', 'M')"));
            entity.HasKey(passenger => passenger.Id);
            entity.Property(passenger => passenger.Id).HasMaxLength(120).HasColumnType("character varying(120)");
            entity.Property(passenger => passenger.Email).HasMaxLength(200).IsRequired().HasColumnType("character varying(200)");
            entity.Property(passenger => passenger.FullName).HasMaxLength(200).IsRequired().HasColumnType("character varying(200)");
            entity.Property(passenger => passenger.Gender).HasMaxLength(1).IsRequired().HasColumnType("character varying(1)");
            entity.HasIndex(passenger => passenger.Email).IsUnique();
        });

        modelBuilder.Entity<Trip>(entity =>
        {
            entity.ToTable("trips", table =>
            {
                table.HasCheckConstraint("CK_trips_delay_minutes", "\"DelayMinutes\" >= 0");
                table.HasCheckConstraint("CK_trips_status", "\"Status\" IN ('Scheduled', 'Started', 'Finished')");
                table.HasCheckConstraint("CK_trips_version", "\"Version\" > 0");
                table.HasCheckConstraint("CK_trips_audience", "\"Audience\" IS NULL OR \"Audience\" IN ('F', 'M')");
                table.HasCheckConstraint("CK_trips_location_coordinate_pair", "(\"CurrentLatitude\" IS NULL AND \"CurrentLongitude\" IS NULL AND \"LocationUpdatedAtUtc\" IS NULL) OR (\"CurrentLatitude\" IS NOT NULL AND \"CurrentLongitude\" IS NOT NULL AND \"LocationUpdatedAtUtc\" IS NOT NULL)");
                table.HasCheckConstraint("CK_trips_current_latitude", "\"CurrentLatitude\" IS NULL OR \"CurrentLatitude\" BETWEEN -90 AND 90");
                table.HasCheckConstraint("CK_trips_current_longitude", "\"CurrentLongitude\" IS NULL OR \"CurrentLongitude\" BETWEEN -180 AND 180");
            });
            entity.HasKey(trip => trip.Id);
            entity.Property(trip => trip.Id).ValueGeneratedOnAdd().HasColumnType("uuid");
            entity.Property(trip => trip.RouteId).HasColumnType("integer");
            entity.Property(trip => trip.Audience).HasMaxLength(1).HasColumnType("character varying(1)");
            entity.Property(trip => trip.BusId).HasColumnType("integer");
            entity.Property(trip => trip.DriverId).HasColumnType("integer");
            entity.Property(trip => trip.DepartureAtUtc).HasColumnType("timestamp with time zone");
            entity.Property(trip => trip.Status).HasConversion<string>().HasMaxLength(16).IsRequired().HasColumnType("character varying(16)");
            entity.Property(trip => trip.DelayMinutes).HasColumnType("integer");
            entity.Property(trip => trip.DelayReason).HasMaxLength(500).HasColumnType("character varying(500)");
            entity.Property(trip => trip.CancellationReason).HasMaxLength(500).HasColumnType("character varying(500)");
            entity.Property(trip => trip.CancelledAtUtc).HasColumnType("timestamp with time zone");
            entity.Property(trip => trip.StartedAtUtc).HasColumnType("timestamp with time zone");
            entity.Property(trip => trip.EndedAtUtc).HasColumnType("timestamp with time zone");
            entity.Property(trip => trip.NearlyFullReportedAtUtc).HasColumnType("timestamp with time zone");
            entity.Property(trip => trip.NearlyFullReportedByDriverId).HasColumnType("integer");
            entity.Property(trip => trip.CurrentLatitude).HasPrecision(9, 6).HasColumnType("numeric(9,6)");
            entity.Property(trip => trip.CurrentLongitude).HasPrecision(9, 6).HasColumnType("numeric(9,6)");
            entity.Property(trip => trip.LocationUpdatedAtUtc).HasColumnType("timestamp with time zone");
            entity.Property(trip => trip.Version).HasColumnType("integer").HasDefaultValue(1).IsConcurrencyToken();
            entity.HasIndex(trip => trip.RouteId);
            entity.HasIndex(trip => trip.BusId);
            entity.HasIndex(trip => trip.DriverId);
            entity.HasIndex(trip => trip.NearlyFullReportedByDriverId);
            entity.HasOne(trip => trip.Route)
                .WithMany(route => route.Trips)
                .HasForeignKey(trip => trip.RouteId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(trip => trip.Bus)
                .WithMany(bus => bus.Trips)
                .HasForeignKey(trip => trip.BusId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(trip => trip.Driver)
                .WithMany(driver => driver.Trips)
                .HasForeignKey(trip => trip.DriverId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(trip => trip.NearlyFullReportedByDriver)
                .WithMany()
                .HasForeignKey(trip => trip.NearlyFullReportedByDriverId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<TripIntent>(entity =>
        {
            entity.ToTable("trip_intents");
            entity.HasKey(intent => intent.Id);
            entity.Property(intent => intent.Id).ValueGeneratedOnAdd().HasColumnType("uuid");
            entity.Property(intent => intent.TripId).HasColumnType("uuid");
            entity.Property(intent => intent.PassengerId).HasMaxLength(120).IsRequired().HasColumnType("character varying(120)");
            entity.Property(intent => intent.DropOffStopId).HasColumnType("integer");
            entity.Property(intent => intent.CreatedAtUtc).HasColumnType("timestamp with time zone");
            entity.Property(intent => intent.CancelledAtUtc).HasColumnType("timestamp with time zone");
            entity.HasIndex(intent => new { intent.TripId, intent.PassengerId })
                .IsUnique()
                .HasFilter("\"CancelledAtUtc\" IS NULL");
            entity.HasIndex(intent => intent.DropOffStopId);
            entity.HasOne(intent => intent.Trip)
                .WithMany(trip => trip.Intents)
                .HasForeignKey(intent => intent.TripId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(intent => intent.DropOffStop)
                .WithMany()
                .HasForeignKey(intent => intent.DropOffStopId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<TripNotification>(entity =>
        {
            entity.ToTable("trip_notifications");
            entity.HasKey(notification => notification.Id);
            entity.Property(notification => notification.Id).ValueGeneratedOnAdd().HasColumnType("uuid");
            entity.Property(notification => notification.TripIntentId).HasColumnType("uuid");
            entity.Property(notification => notification.Type).HasConversion<string>()
                .HasMaxLength(40).IsRequired().HasColumnType("character varying(40)");
            entity.Property(notification => notification.Title).HasMaxLength(120)
                .IsRequired().HasColumnType("character varying(120)");
            entity.Property(notification => notification.Message).HasMaxLength(500)
                .IsRequired().HasColumnType("character varying(500)");
            entity.Property(notification => notification.DeduplicationKey).HasMaxLength(128)
                .IsRequired().HasColumnType("character varying(128)");
            entity.Property(notification => notification.CreatedAtUtc).HasColumnType("timestamp with time zone");
            entity.Property(notification => notification.ReadAtUtc).HasColumnType("timestamp with time zone");
            entity.HasIndex(notification => new { notification.TripIntentId, notification.DeduplicationKey })
                .IsUnique();
            entity.HasIndex(notification => new { notification.TripIntentId, notification.CreatedAtUtc });
            entity.HasOne(notification => notification.TripIntent)
                .WithMany(intent => intent.Notifications)
                .HasForeignKey(notification => notification.TripIntentId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}
