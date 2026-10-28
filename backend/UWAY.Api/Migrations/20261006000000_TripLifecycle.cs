using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using UWAY.Api.Data;

#nullable disable

namespace UWAY.Api.Migrations;

[DbContext(typeof(UwayDbContext))]
[Migration("20261006000000_TripLifecycle")]
public sealed class TripLifecycle : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<string>(
            name: "DelayReason",
            table: "trips",
            type: "character varying(500)",
            maxLength: 500,
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "CancellationReason",
            table: "trips",
            type: "character varying(500)",
            maxLength: 500,
            nullable: true);

        migrationBuilder.AddColumn<DateTimeOffset>(
            name: "CancelledAtUtc",
            table: "trips",
            type: "timestamp with time zone",
            nullable: true);

        migrationBuilder.AddColumn<int>(
            name: "Version",
            table: "trips",
            type: "integer",
            nullable: false,
            defaultValue: 1);

        migrationBuilder.AddCheckConstraint(
            name: "CK_trips_version",
            table: "trips",
            sql: "\"Version\" > 0");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropCheckConstraint(name: "CK_trips_version", table: "trips");
        migrationBuilder.DropColumn(name: "DelayReason", table: "trips");
        migrationBuilder.DropColumn(name: "CancellationReason", table: "trips");
        migrationBuilder.DropColumn(name: "CancelledAtUtc", table: "trips");
        migrationBuilder.DropColumn(name: "Version", table: "trips");
    }
}
