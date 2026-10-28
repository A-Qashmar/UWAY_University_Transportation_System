using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using UWAY.Api.Data;

#nullable disable

namespace UWAY.Api.Migrations;

[DbContext(typeof(UwayDbContext))]
[Migration("20261007000000_TripIntentDropOffStop")]
public sealed class TripIntentDropOffStop : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<int>(
            name: "DropOffStopId",
            table: "trip_intents",
            type: "integer",
            nullable: true);

        migrationBuilder.CreateIndex(
            name: "IX_trip_intents_DropOffStopId",
            table: "trip_intents",
            column: "DropOffStopId");

        migrationBuilder.AddForeignKey(
            name: "FK_trip_intents_stops_DropOffStopId",
            table: "trip_intents",
            column: "DropOffStopId",
            principalTable: "stops",
            principalColumn: "Id",
            onDelete: ReferentialAction.Restrict);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropForeignKey(
            name: "FK_trip_intents_stops_DropOffStopId",
            table: "trip_intents");

        migrationBuilder.DropIndex(
            name: "IX_trip_intents_DropOffStopId",
            table: "trip_intents");

        migrationBuilder.DropColumn(
            name: "DropOffStopId",
            table: "trip_intents");
    }
}
