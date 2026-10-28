using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using UWAY.Api.Data;

#nullable disable

namespace UWAY.Api.Migrations;

/// <summary>
/// A trip's status is now only Scheduled, Started or Finished. Delays and
/// cancellations are alerts carried by DelayMinutes and CancelledAtUtc, which
/// already exist, so no column is added or removed.
/// </summary>
[DbContext(typeof(UwayDbContext))]
[Migration("20261026140000_TripStatusLifecycle")]
public sealed class TripStatusLifecycle : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("ALTER TABLE trips DROP CONSTRAINT IF EXISTS \"CK_trips_status\";");
        migrationBuilder.Sql("UPDATE trips SET \"Status\" = 'Started' WHERE \"Status\" = 'InProgress';");
        migrationBuilder.Sql("UPDATE trips SET \"Status\" = 'Finished' WHERE \"Status\" = 'Completed';");
        migrationBuilder.Sql("UPDATE trips SET \"Status\" = CASE WHEN \"StartedAtUtc\" IS NOT NULL THEN 'Started' ELSE 'Scheduled' END WHERE \"Status\" = 'Cancelled';");
        migrationBuilder.Sql("UPDATE trips SET \"Status\" = 'Scheduled' WHERE \"Status\" = 'Delayed';");
        migrationBuilder.Sql("ALTER TABLE trips ADD CONSTRAINT \"CK_trips_status\" CHECK (\"Status\" IN ('Scheduled', 'Started', 'Finished'));");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("ALTER TABLE trips DROP CONSTRAINT IF EXISTS \"CK_trips_status\";");
        migrationBuilder.Sql("UPDATE trips SET \"Status\" = 'Cancelled' WHERE \"CancelledAtUtc\" IS NOT NULL;");
        migrationBuilder.Sql("UPDATE trips SET \"Status\" = 'Delayed' WHERE \"Status\" = 'Scheduled' AND \"DelayMinutes\" > 0;");
        migrationBuilder.Sql("UPDATE trips SET \"Status\" = 'InProgress' WHERE \"Status\" = 'Started';");
        migrationBuilder.Sql("UPDATE trips SET \"Status\" = 'Completed' WHERE \"Status\" = 'Finished';");
        migrationBuilder.Sql("ALTER TABLE trips ADD CONSTRAINT \"CK_trips_status\" CHECK (\"Status\" IN ('Scheduled', 'InProgress', 'Delayed', 'Cancelled', 'Completed'));");
    }
}
