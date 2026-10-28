using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using UWAY.Api.Data;

#nullable disable

namespace UWAY.Api.Migrations;

/// <summary>
/// Women's and men's trips are separate. A trip carries an Audience ("F" or
/// "M") chosen by the Admin; a passenger profile carries the matching Gender.
/// Trips created before this change keep a NULL audience and are not shown
/// to any passenger until the Admin recreates them with an audience.
/// Two clearly fake test passengers are added for local testing.
/// </summary>
[DbContext(typeof(UwayDbContext))]
[Migration("20261027120000_PassengerGenderAndTripAudience")]
public sealed class PassengerGenderAndTripAudience : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("ALTER TABLE trips ADD COLUMN \"Audience\" character varying(1) NULL;");
        migrationBuilder.Sql("ALTER TABLE trips ADD CONSTRAINT \"CK_trips_audience\" CHECK (\"Audience\" IS NULL OR \"Audience\" IN ('F', 'M'));");
        migrationBuilder.Sql(@"CREATE TABLE passengers (
            ""Id"" character varying(120) NOT NULL,
            ""Email"" character varying(200) NOT NULL,
            ""FullName"" character varying(200) NOT NULL,
            ""Gender"" character varying(1) NOT NULL,
            CONSTRAINT ""PK_passengers"" PRIMARY KEY (""Id""),
            CONSTRAINT ""CK_passengers_gender"" CHECK (""Gender"" IN ('F', 'M'))
        );");
        migrationBuilder.Sql("CREATE UNIQUE INDEX \"IX_passengers_Email\" ON passengers (\"Email\");");
        migrationBuilder.Sql("INSERT INTO passengers (\"Id\", \"Email\", \"FullName\", \"Gender\") VALUES " +
            "('test-female-1', 'female.test@uway.test', 'Test Female Student', 'F'), " +
            "('test-male-1', 'male.test@uway.test', 'Test Male Student', 'M');");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("DROP TABLE IF EXISTS passengers;");
        migrationBuilder.Sql("ALTER TABLE trips DROP CONSTRAINT IF EXISTS \"CK_trips_audience\";");
        migrationBuilder.Sql("ALTER TABLE trips DROP COLUMN IF EXISTS \"Audience\";");
    }
}
