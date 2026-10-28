using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using UWAY.Api.Data;

#nullable disable

namespace UWAY.Api.Migrations;

[DbContext(typeof(UwayDbContext))]
[Migration("20261007120000_DriverNearlyFullReport")]
public sealed class DriverNearlyFullReport : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<DateTimeOffset>(
            name: "NearlyFullReportedAtUtc",
            table: "trips",
            type: "timestamp with time zone",
            nullable: true);

        migrationBuilder.AddColumn<int>(
            name: "NearlyFullReportedByDriverId",
            table: "trips",
            type: "integer",
            nullable: true);

        migrationBuilder.CreateIndex(
            name: "IX_trips_NearlyFullReportedByDriverId",
            table: "trips",
            column: "NearlyFullReportedByDriverId");

        migrationBuilder.AddForeignKey(
            name: "FK_trips_drivers_NearlyFullReportedByDriverId",
            table: "trips",
            column: "NearlyFullReportedByDriverId",
            principalTable: "drivers",
            principalColumn: "Id",
            onDelete: ReferentialAction.Restrict);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropForeignKey(
            name: "FK_trips_drivers_NearlyFullReportedByDriverId",
            table: "trips");

        migrationBuilder.DropIndex(
            name: "IX_trips_NearlyFullReportedByDriverId",
            table: "trips");

        migrationBuilder.DropColumn(
            name: "NearlyFullReportedAtUtc",
            table: "trips");

        migrationBuilder.DropColumn(
            name: "NearlyFullReportedByDriverId",
            table: "trips");
    }
}
