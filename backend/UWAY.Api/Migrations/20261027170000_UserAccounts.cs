using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using UWAY.Api.Data;

#nullable disable

namespace UWAY.Api.Migrations;

/// <summary>Sign-in accounts (email and password hash) for Passenger, Driver and Admin.</summary>
[DbContext(typeof(UwayDbContext))]
[Migration("20261027170000_UserAccounts")]
public sealed class UserAccounts : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql(@"CREATE TABLE users (
            ""Id"" uuid NOT NULL,
            ""Email"" character varying(200) NOT NULL,
            ""PasswordHash"" character varying(300) NOT NULL,
            ""Role"" character varying(16) NOT NULL,
            ""FullName"" character varying(200) NOT NULL,
            ""DriverId"" integer NULL,
            ""IsActive"" boolean NOT NULL,
            ""CreatedAtUtc"" timestamp with time zone NOT NULL,
            CONSTRAINT ""PK_users"" PRIMARY KEY (""Id""),
            CONSTRAINT ""FK_users_drivers_DriverId"" FOREIGN KEY (""DriverId"") REFERENCES drivers (""Id"") ON DELETE SET NULL,
            CONSTRAINT ""CK_users_role"" CHECK (""Role"" IN ('Passenger', 'Driver', 'Admin')),
            CONSTRAINT ""CK_users_email_lower"" CHECK (""Email"" = lower(""Email""))
        );");
        migrationBuilder.Sql("CREATE UNIQUE INDEX \"IX_users_Email\" ON users (\"Email\");");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("DROP TABLE IF EXISTS users;");
    }
}
