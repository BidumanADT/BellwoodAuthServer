using System.Diagnostics;
using Serilog;
using Serilog.Context;

namespace BellwoodAuthServer.Middleware;

public class RequestLoggingMiddleware
{
    private readonly RequestDelegate _next;

    public RequestLoggingMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task Invoke(HttpContext context)
    {
        var stopwatch = Stopwatch.StartNew();
        using (LogContext.PushProperty("requestPath", context.Request.Path.Value ?? string.Empty))
        using (LogContext.PushProperty("method", context.Request.Method))
        {
            try
            {
                await _next(context);

                stopwatch.Stop();
                var userId = context.User?.FindFirst("userId")?.Value ?? context.User?.FindFirst("sub")?.Value;
                using (LogContext.PushProperty("statusCode", context.Response.StatusCode))
                using (LogContext.PushProperty("elapsedMs", stopwatch.ElapsedMilliseconds))
                using (LogContext.PushProperty("userId", userId ?? string.Empty))
                {
                    Log.Information("Request completed");
                }
            }
            catch (Exception ex)
            {
                stopwatch.Stop();
                var errorId = Guid.NewGuid().ToString("N");
                context.Response.Headers["X-Error-Id"] = errorId;

                var userId = context.User?.FindFirst("userId")?.Value ?? context.User?.FindFirst("sub")?.Value;
                using (LogContext.PushProperty("statusCode", 500))
                using (LogContext.PushProperty("elapsedMs", stopwatch.ElapsedMilliseconds))
                using (LogContext.PushProperty("errorId", errorId))
                using (LogContext.PushProperty("userId", userId ?? string.Empty))
                {
                    Log.Error(ex, "Unhandled exception processing request");
                }

                throw;
            }
        }
    }
}
