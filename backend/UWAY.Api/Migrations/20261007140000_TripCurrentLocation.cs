using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using UWAY.Api.Data;

#nullable disable

namespace UWAY.Api.Migrations;

[DbContext(typeof(UwayDbContext))]
[Migration("20261007140000_TripCurrentLocation")]
public sealed class TripCurrentLocation : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<decimal>(
            name: "CurrentLatitude",
            table: "trips",
            type: "numeric(9,6)",
            precision: 9,
            scale: 6,
            nullable: true);

        migrationBuilder.AddColumn<decimal>(
            name: "CurrentLongitude",
            table: "trips",
            type: "numeric(9,6)",
            precision: 9,
            scale: 6,
            nullable: true);

        migrationBuilder.AddColumn<DateTimeOffset>(
            name: "LocationUpdatedAtUtc",
            table: "trips",
            type: "timestamp with time zone",
            nullable: true);

        migrationBuilder.AddCheckConstraint(
            name: "CK_trips_location_coordinate_pair",
            table: "trips",
            sql: "(\"CurrentLatitude\" IS NULL AND \"CurrentLongitude\" IS NULL AND \"LocationUpdatedAtUtc\" IS NULL) OR (\"CurrentLatitude\" IS NOT NULL AND \"CurrentLongitude\" IS NOT NULL AND \"LocationUpdatedAtUtc\" IS NOT NULL)");

        migrationBuilder.AddCheckConstraint(
            name: "CK_trips_current_latitude",
            table: "trips",
            sql: "\"CurrentLatitude\" IS NULL OR \"CurrentLatitude\" BETWEEN -90 AND 90");

        migrationBuilder.AddCheckConstraint(
            name: "CK_trips_current_longitude",
            table: "trips",
            sql: "\"CurrentLongitude\" IS NULL OR \"CurrentLongitude\" BETWEEN -180 AND 180");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropCheckConstraint("CK_trips_current_longitude", "trips");
        migrationBuilder.DropCheckConstraint("CK_trips_current_latitude", "trips");
        migrationBuilder.DropCheckConstraint("CK_trips_location_coordinate_pair", "trips");
        migrationBuilder.DropColumn("CurrentLatitude", "trips");
        migrationBuilder.DropColumn("CurrentLongitude", "trips");
        migrationBuilder.DropColumn("LocationUpdatedAtUtc", "trips");
    }
}
