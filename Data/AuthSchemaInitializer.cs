using Microsoft.EntityFrameworkCore;

namespace BellwoodAuthServer.Data
{
    /// <summary>
    /// Provides helpers for ensuring critical parts of the database schema exist at runtime.
    /// In particular, this ensures that the AuthAuditEvents table is created even if a prior
    /// migration was empty or skipped. Idempotent SQL statements allow safe repeated execution.
    /// </summary>
    public static class AuthSchemaInitializer
    {
        /// <summary>
        /// Create the AuthAuditEvents table if it does not already exist.
        /// </summary>
        /// <param name="db">An initialized DbContext.</param>
        public static void EnsureAuditTableExists(DbContext db)
        {
            // SQLite supports CREATE TABLE IF NOT EXISTS.  Using raw SQL avoids exceptions when the table already exists.
            const string createAuditTableSql = @"
                CREATE TABLE IF NOT EXISTS ""AuthAuditEvents"" (
                    ""Id"" INTEGER NOT NULL CONSTRAINT ""PK_AuthAuditEvents"" PRIMARY KEY AUTOINCREMENT,
                    ""TimestampUtc"" TEXT NOT NULL,
                    ""Username"" TEXT NULL,
                    ""Action"" TEXT NOT NULL,
                    ""Result"" TEXT NOT NULL,
                    ""CorrelationId"" TEXT NULL,
                    ""IpAddress"" TEXT NULL,
                    ""UserAgent"" TEXT NULL
                );
            ";
            db.Database.ExecuteSqlRaw(createAuditTableSql);
        }
    }
}
