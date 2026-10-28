using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using UWAY.Api.Data;

#nullable disable

namespace UWAY.Api.Migrations;

/// <summary>Passenger reports (lost items, trip problems) with an Admin status and reply.</summary>
[DbContext(typeof(UwayDbContext))]
[Migration("20261027150000_PassengerReports")]
public sealed class PassengerReports : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql(@"CREATE TABLE reports (
            ""Id"" uuid NOT NULL,
            ""PassengerId"" character varying(120) NOT NULL,
            ""Category"" character varying(24) NOT NULL,
            ""TripId"" uuid NULL,
            ""Description"" character varying(1000) NOT NULL,
            ""Status"" character varying(16) NOT NULL,
            ""AdminResponse"" character varying(1000) NULL,
            ""CreatedAtUtc"" timestamp with time zone NOT NULL,
            ""UpdatedAtUtc"" timestamp with time zone NOT NULL,
            CONSTRAINT ""PK_reports"" PRIMARY KEY (""Id""),
            CONSTRAINT ""FK_reports_trips_TripId"" FOREIGN KEY (""TripId"") REFERENCES trips (""Id"") ON DELETE SET NULL,
            CONSTRAINT ""CK_reports_category"" CHECK (""Category"" IN ('LostItem', 'TripProblem', 'DriverOrBus', 'Other')),
            CONSTRAINT ""CK_reports_status"" CHECK (""Status"" IN ('Open', 'InReview', 'Resolved'))
        );");
        migrationBuilder.Sql("CREATE INDEX \"IX_reports_PassengerId_CreatedAtUtc\" ON reports (\"PassengerId\", \"CreatedAtUtc\");");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("DROP TABLE IF EXISTS reports;");
    }
}
