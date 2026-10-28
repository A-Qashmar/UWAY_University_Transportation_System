using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using UWAY.Api.Data;

#nullable disable

namespace UWAY.Api.Migrations;

[DbContext(typeof(UwayDbContext))]
[Migration("20261008090000_TripNotificationInbox")]
public sealed class TripNotificationInbox : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "trip_notifications",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uuid", nullable: false),
                TripIntentId = table.Column<Guid>(type: "uuid", nullable: false),
                Type = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                Title = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                Message = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                DeduplicationKey = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                CreatedAtUtc = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                ReadAtUtc = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_trip_notifications", x => x.Id);
                table.ForeignKey(
                    name: "FK_trip_notifications_trip_intents_TripIntentId",
                    column: x => x.TripIntentId,
                    principalTable: "trip_intents",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_trip_notifications_TripIntentId_CreatedAtUtc",
            table: "trip_notifications",
            columns: new[] { "TripIntentId", "CreatedAtUtc" });

        migrationBuilder.CreateIndex(
            name: "IX_trip_notifications_TripIntentId_DeduplicationKey",
            table: "trip_notifications",
            columns: new[] { "TripIntentId", "DeduplicationKey" },
            unique: true);
    }

    protected override void Down(MigrationBuilder migrationBuilder) =>
        migrationBuilder.DropTable(name: "trip_notifications");
}
