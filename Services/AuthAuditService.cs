using BellwoodAuthServer.Data;
using BellwoodAuthServer.Middleware;
using BellwoodAuthServer.Models;
using Microsoft.Data.Sqlite;
using Serilog;

namespace BellwoodAuthServer.Services;

public class AuthAuditService
{
    private const int MaxUserAgentLength = 200;

    private readonly ApplicationDbContext _dbContext;

    public AuthAuditService(ApplicationDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task LogEventAsync(HttpContext httpContext, string? username, string action, string result)
    {
        var correlationId = httpContext.Items.TryGetValue(CorrelationIdMiddleware.CorrelationItemKey, out var correlation)
            ? correlation?.ToString()
            : null;

        var rawUserAgent = httpContext.Request.Headers.UserAgent.ToString();
        var userAgent = rawUserAgent.Length > MaxUserAgentLength
            ? rawUserAgent[..MaxUserAgentLength] + "..."
            : rawUserAgent;

        var auditEvent = new AuthAuditEvent
        {
            TimestampUtc = DateTime.UtcNow,
            Username = username,
            Action = action,
            Result = result,
            CorrelationId = correlationId,
            IpAddress = httpContext.Connection.RemoteIpAddress?.ToString(),
            UserAgent = userAgent
        };

        try
        {
            _dbContext.AuthAuditEvents.Add(auditEvent);
            await _dbContext.SaveChangesAsync(httpContext.RequestAborted);
        }
        catch (OperationCanceledException)
        {
            // Request was aborted — discard quietly, audit is best-effort
        }
        catch (Exception ex)
        {
            // Audit failure must never crash the request — log as WARNING, not ERROR
            Log.Warning(ex,
                "Audit log write failed (non-fatal). username={Username} action={Action} result={Result} correlationId={CorrelationId}",
                username, action, result, correlationId);

            // Extra hint for the most common cold-start failure (migrations not applied)
            var root = ex;
            while (root.InnerException is not null)
            {
                root = root.InnerException;
            }

            if (root is SqliteException sqliteEx &&
                sqliteEx.Message.Contains("no such table", StringComparison.OrdinalIgnoreCase))
            {
                Log.Warning(
                    "Audit table missing — schema may not have been migrated. Run 'dotnet ef database update' or ensure MigrateAsync() completed successfully.");
            }
        }
    }
}
