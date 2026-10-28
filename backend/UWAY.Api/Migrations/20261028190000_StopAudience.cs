using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using UWAY.Api.Data;

#nullable disable

namespace UWAY.Api.Migrations;

/// <summary>Men-only and women-only stops (UOS - M3 and UOS - W3).</summary>
[DbContext(typeof(UwayDbContext))]
[Migration("20261028190000_StopAudience")]
public sealed class StopAudience : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("ALTER TABLE stops ADD COLUMN IF NOT EXISTS \"Audience\" character varying(1) NULL;");
        migrationBuilder.Sql("UPDATE stops SET \"Audience\" = 'M' WHERE \"Name\" = 'UOS - M3';");
        migrationBuilder.Sql("UPDATE stops SET \"Audience\" = 'F' WHERE \"Name\" = 'UOS - W3';");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("ALTER TABLE stops DROP COLUMN IF EXISTS \"Audience\";");
    }
}
