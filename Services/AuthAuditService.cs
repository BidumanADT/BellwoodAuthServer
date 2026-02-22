using BellwoodAuthServer.Data;
using BellwoodAuthServer.Models;

namespace BellwoodAuthServer.Services;

public class AuthAuditService
{
    private readonly ApplicationDbContext _dbContext;

    public AuthAuditService(ApplicationDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task LogEventAsync(HttpContext httpContext, string? username, string action, string result)
    {
        var auditEvent = new AuthAuditEvent
        {
            TimestampUtc = DateTime.UtcNow,
            Username = username,
            Action = action,
            Result = result,
            CorrelationId = httpContext.Items.TryGetValue(CorrelationIdMiddleware.CorrelationItemKey, out var correlation)
                ? correlation?.ToString()
                : null,
            IpAddress = httpContext.Connection.RemoteIpAddress?.ToString(),
            UserAgent = httpContext.Request.Headers.UserAgent.ToString()
        };

        _dbContext.AuthAuditEvents.Add(auditEvent);
        await _dbContext.SaveChangesAsync();
    }
}
