using Serilog.Context;

namespace BellwoodAuthServer.Middleware;

public class CorrelationIdMiddleware
{
    public const string CorrelationHeader = "X-Correlation-Id";
    public const string CorrelationItemKey = "CorrelationId";

    private readonly RequestDelegate _next;

    public CorrelationIdMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task Invoke(HttpContext context)
    {
        var correlationId = context.Request.Headers.TryGetValue(CorrelationHeader, out var headerValue)
            && !string.IsNullOrWhiteSpace(headerValue)
                ? headerValue.ToString()
                : Guid.NewGuid().ToString("D");

        context.Items[CorrelationItemKey] = correlationId;
        context.Response.Headers[CorrelationHeader] = correlationId;

        using (LogContext.PushProperty("correlationId", correlationId))
        {
            await _next(context);
        }
    }
}
