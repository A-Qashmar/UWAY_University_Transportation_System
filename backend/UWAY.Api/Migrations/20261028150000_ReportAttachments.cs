using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using UWAY.Api.Data;

#nullable disable

namespace UWAY.Api.Migrations;

/// <summary>Photos and videos attached to reports.</summary>
[DbContext(typeof(UwayDbContext))]
[Migration("20261028150000_ReportAttachments")]
public sealed class ReportAttachments : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql(@"CREATE TABLE report_attachments (
            ""Id"" uuid NOT NULL,
            ""ReportId"" uuid NOT NULL,
            ""FileName"" character varying(200) NOT NULL,
            ""ContentType"" character varying(100) NOT NULL,
            ""SizeBytes"" bigint NOT NULL,
            ""Data"" bytea NOT NULL,
            ""CreatedAtUtc"" timestamp with time zone NOT NULL,
            CONSTRAINT ""PK_report_attachments"" PRIMARY KEY (""Id""),
            CONSTRAINT ""FK_report_attachments_reports_ReportId"" FOREIGN KEY (""ReportId"") REFERENCES reports (""Id"") ON DELETE CASCADE
        );");
        migrationBuilder.Sql("CREATE INDEX \"IX_report_attachments_ReportId\" ON report_attachments (\"ReportId\");");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("DROP TABLE IF EXISTS report_attachments;");
    }
}
