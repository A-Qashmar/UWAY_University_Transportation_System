using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using UWAY.Api.Data;

#nullable disable

namespace UWAY.Api.Migrations;

/// <summary>Inbox messages for admins, drivers and report updates for any user.</summary>
[DbContext(typeof(UwayDbContext))]
[Migration("20261028110000_UserNotifications")]
public sealed class UserNotifications : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql(@"CREATE TABLE user_notifications (
            ""Id"" uuid NOT NULL,
            ""UserId"" character varying(120) NOT NULL,
            ""Type"" character varying(40) NOT NULL,
            ""Title"" character varying(120) NOT NULL,
            ""Message"" character varying(500) NOT NULL,
            ""TripId"" uuid NULL,
            ""DeduplicationKey"" character varying(128) NOT NULL,
            ""CreatedAtUtc"" timestamp with time zone NOT NULL,
            ""ReadAtUtc"" timestamp with time zone NULL,
            CONSTRAINT ""PK_user_notifications"" PRIMARY KEY (""Id"")
        );");
        migrationBuilder.Sql("CREATE UNIQUE INDEX \"IX_user_notifications_UserId_DeduplicationKey\" ON user_notifications (\"UserId\", \"DeduplicationKey\");");
        migrationBuilder.Sql("CREATE INDEX \"IX_user_notifications_UserId_CreatedAtUtc\" ON user_notifications (\"UserId\", \"CreatedAtUtc\");");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("DROP TABLE IF EXISTS user_notifications;");
    }
}
