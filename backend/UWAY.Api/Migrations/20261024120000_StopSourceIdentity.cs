using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using UWAY.Api.Data;

#nullable disable

namespace UWAY.Api.Migrations;

[DbContext(typeof(UwayDbContext))]
[Migration("20261024120000_StopSourceIdentity")]
public sealed class StopSourceIdentity : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<string>(
            name: "SourceGroup",
            table: "stops",
            type: "character varying(80)",
            maxLength: 80,
            nullable: true);

        migrationBuilder.AddColumn<string>(
            name: "SourceKey",
            table: "stops",
            type: "character varying(64)",
            maxLength: 64,
            nullable: true);

        migrationBuilder.CreateIndex(
            name: "IX_stops_SourceKey",
            table: "stops",
            column: "SourceKey",
            unique: true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropIndex(name: "IX_stops_SourceKey", table: "stops");
        migrationBuilder.DropColumn(name: "SourceGroup", table: "stops");
        migrationBuilder.DropColumn(name: "SourceKey", table: "stops");
    }
}
