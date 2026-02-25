namespace BellwoodAuthServer.Models;

public class AuthAuditEvent
{
    public long Id { get; set; }
    public DateTime TimestampUtc { get; set; }
    public string? Username { get; set; }
    public string Action { get; set; } = string.Empty;
    public string Result { get; set; } = string.Empty;
    public string? CorrelationId { get; set; }
    public string? IpAddress { get; set; }
    public string? UserAgent { get; set; }
}
