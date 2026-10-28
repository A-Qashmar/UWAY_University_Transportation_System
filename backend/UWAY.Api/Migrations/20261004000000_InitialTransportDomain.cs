using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;
using UWAY.Api.Data;

#nullable disable

namespace UWAY.Api.Migrations;

[DbContext(typeof(UwayDbContext))]
[Migration("20261004000000_InitialTransportDomain")]
public sealed class InitialTransportDomain : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "buses",
            columns: table => new
            {
                Id = table.Column<int>(type: "integer", nullable: false)
                    .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                FleetNumber = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                Capacity = table.Column<int>(type: "integer", nullable: false),
                IsActive = table.Column<bool>(type: "boolean", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_buses", x => x.Id);
                table.CheckConstraint("CK_buses_capacity", "\"Capacity\" > 0");
            });

        migrationBuilder.CreateTable(
            name: "drivers",
            columns: table => new
            {
                Id = table.Column<int>(type: "integer", nullable: false)
                    .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                FullName = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                PhoneNumber = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: true),
                IsActive = table.Column<bool>(type: "boolean", nullable: false)
            },
            constraints: table => table.PrimaryKey("PK_drivers", x => x.Id));

        migrationBuilder.CreateTable(
            name: "routes",
            columns: table => new
            {
                Id = table.Column<int>(type: "integer", nullable: false)
                    .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                Code = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                Name = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                IsActive = table.Column<bool>(type: "boolean", nullable: false)
            },
            constraints: table => table.PrimaryKey("PK_routes", x => x.Id));

        migrationBuilder.CreateTable(
            name: "stops",
            columns: table => new
            {
                Id = table.Column<int>(type: "integer", nullable: false)
                    .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                Name = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                Latitude = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: true),
                Longitude = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: true),
                IsActive = table.Column<bool>(type: "boolean", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_stops", x => x.Id);
                table.CheckConstraint("CK_stops_coordinate_pair", "(\"Latitude\" IS NULL AND \"Longitude\" IS NULL) OR (\"Latitude\" IS NOT NULL AND \"Longitude\" IS NOT NULL)");
                table.CheckConstraint("CK_stops_latitude", "\"Latitude\" IS NULL OR \"Latitude\" BETWEEN -90 AND 90");
                table.CheckConstraint("CK_stops_longitude", "\"Longitude\" IS NULL OR \"Longitude\" BETWEEN -180 AND 180");
            });

        migrationBuilder.CreateTable(
            name: "trips",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uuid", nullable: false),
                RouteId = table.Column<int>(type: "integer", nullable: false),
                BusId = table.Column<int>(type: "integer", nullable: true),
                DriverId = table.Column<int>(type: "integer", nullable: true),
                DepartureAtUtc = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                Status = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                DelayMinutes = table.Column<int>(type: "integer", nullable: false),
                StartedAtUtc = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                EndedAtUtc = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_trips", x => x.Id);
                table.CheckConstraint("CK_trips_delay_minutes", "\"DelayMinutes\" >= 0");
                table.CheckConstraint("CK_trips_status", "\"Status\" IN ('Scheduled', 'InProgress', 'Delayed', 'Cancelled', 'Completed')");
                table.ForeignKey("FK_trips_buses_BusId", x => x.BusId, "buses", "Id", onDelete: ReferentialAction.Restrict);
                table.ForeignKey("FK_trips_drivers_DriverId", x => x.DriverId, "drivers", "Id", onDelete: ReferentialAction.Restrict);
                table.ForeignKey("FK_trips_routes_RouteId", x => x.RouteId, "routes", "Id", onDelete: ReferentialAction.Restrict);
            });

        migrationBuilder.CreateTable(
            name: "route_stops",
            columns: table => new
            {
                RouteId = table.Column<int>(type: "integer", nullable: false),
                StopId = table.Column<int>(type: "integer", nullable: false),
                StopOrder = table.Column<int>(type: "integer", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_route_stops", x => new { x.RouteId, x.StopId });
                table.CheckConstraint("CK_route_stops_order", "\"StopOrder\" > 0");
                table.ForeignKey("FK_route_stops_routes_RouteId", x => x.RouteId, "routes", "Id", onDelete: ReferentialAction.Cascade);
                table.ForeignKey("FK_route_stops_stops_StopId", x => x.StopId, "stops", "Id", onDelete: ReferentialAction.Restrict);
            });

        migrationBuilder.CreateTable(
            name: "trip_intents",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uuid", nullable: false),
                TripId = table.Column<Guid>(type: "uuid", nullable: false),
                PassengerId = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                CreatedAtUtc = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                CancelledAtUtc = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_trip_intents", x => x.Id);
                table.ForeignKey("FK_trip_intents_trips_TripId", x => x.TripId, "trips", "Id", onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(name: "IX_buses_FleetNumber", table: "buses", column: "FleetNumber", unique: true);
        migrationBuilder.CreateIndex(name: "IX_routes_Code", table: "routes", column: "Code", unique: true);
        migrationBuilder.CreateIndex(name: "IX_route_stops_RouteId_StopOrder", table: "route_stops", columns: new[] { "RouteId", "StopOrder" }, unique: true);
        migrationBuilder.CreateIndex(name: "IX_route_stops_StopId", table: "route_stops", column: "StopId");
        migrationBuilder.CreateIndex(name: "IX_trips_BusId", table: "trips", column: "BusId");
        migrationBuilder.CreateIndex(name: "IX_trips_DriverId", table: "trips", column: "DriverId");
        migrationBuilder.CreateIndex(name: "IX_trips_RouteId", table: "trips", column: "RouteId");
        migrationBuilder.CreateIndex(name: "IX_trip_intents_TripId", table: "trip_intents", column: "TripId");
        migrationBuilder.CreateIndex(name: "IX_trip_intents_TripId_PassengerId", table: "trip_intents", columns: new[] { "TripId", "PassengerId" }, unique: true, filter: "\"CancelledAtUtc\" IS NULL");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "route_stops");
        migrationBuilder.DropTable(name: "trip_intents");
        migrationBuilder.DropTable(name: "stops");
        migrationBuilder.DropTable(name: "trips");
        migrationBuilder.DropTable(name: "buses");
        migrationBuilder.DropTable(name: "drivers");
        migrationBuilder.DropTable(name: "routes");
    }
}
