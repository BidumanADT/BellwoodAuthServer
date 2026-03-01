using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BellwoodAuthServer.Migrations
{
    /// <inheritdoc />
    public partial class AddAuthAuditEvents : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Create AuthAuditEvents table if it doesn't already exist.  Raw SQL makes this idempotent.
            migrationBuilder.Sql(
                @"CREATE TABLE IF NOT EXISTS ""AuthAuditEvents"" (
                    ""Id"" INTEGER NOT NULL CONSTRAINT ""PK_AuthAuditEvents"" PRIMARY KEY AUTOINCREMENT,
                    ""TimestampUtc"" TEXT NOT NULL,
                    ""Username"" TEXT NULL,
                    ""Action"" TEXT NOT NULL,
                    ""Result"" TEXT NOT NULL,
                    ""CorrelationId"" TEXT NULL,
                    ""IpAddress"" TEXT NULL,
                    ""UserAgent"" TEXT NULL
                );");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Drop the audit table on rollback.  IF EXISTS avoids errors if the table has already been dropped.
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""AuthAuditEvents"";");
        }
    }
}
