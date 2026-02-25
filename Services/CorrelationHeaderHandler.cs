namespace BellwoodAuthServer.Services;

public class CorrelationHeaderHandler : DelegatingHandler
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public CorrelationHeaderHandler(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var context = _httpContextAccessor.HttpContext;
        if (context != null &&
            context.Items.TryGetValue(Middleware.CorrelationIdMiddleware.CorrelationItemKey, out var correlationId) &&
            correlationId is string value &&
            !request.Headers.Contains(Middleware.CorrelationIdMiddleware.CorrelationHeader))
        {
            request.Headers.TryAddWithoutValidation(Middleware.CorrelationIdMiddleware.CorrelationHeader, value);
        }

        return base.SendAsync(request, cancellationToken);
    }
}
