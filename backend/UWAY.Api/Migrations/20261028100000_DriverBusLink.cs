using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using UWAY.Api.Data;

#nullable disable

namespace UWAY.Api.Migrations;

/// <summary>A driver can be linked to the bus they normally drive (one driver per bus).</summary>
[DbContext(typeof(UwayDbContext))]
[Migration("20261028100000_DriverBusLink")]
public sealed class DriverBusLink : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("ALTER TABLE drivers ADD COLUMN \"AssignedBusId\" integer NULL;");
        migrationBuilder.Sql("ALTER TABLE drivers ADD CONSTRAINT \"FK_drivers_buses_AssignedBusId\" FOREIGN KEY (\"AssignedBusId\") REFERENCES buses (\"Id\") ON DELETE SET NULL;");
        migrationBuilder.Sql("CREATE UNIQUE INDEX \"IX_drivers_AssignedBusId\" ON drivers (\"AssignedBusId\");");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("DROP INDEX IF EXISTS \"IX_drivers_AssignedBusId\";");
        migrationBuilder.Sql("ALTER TABLE drivers DROP CONSTRAINT IF EXISTS \"FK_drivers_buses_AssignedBusId\";");
        migrationBuilder.Sql("ALTER TABLE drivers DROP COLUMN IF EXISTS \"AssignedBusId\";");
    }
}
