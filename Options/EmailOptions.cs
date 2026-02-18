namespace BellwoodAuthServer.Options;

public class EmailOptions
{
    public string Mode { get; set; } = "Disabled";
    public SmtpOptions Smtp { get; set; } = new();
    public OverrideRecipientsOptions OverrideRecipients { get; set; } = new();
    public bool IncludeOriginalRecipientInSubject { get; set; }
}

public class SmtpOptions
{
    public string Host { get; set; } = string.Empty;
    public int Port { get; set; } = 25;
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string From { get; set; } = string.Empty;
}

public class OverrideRecipientsOptions
{
    public bool Enabled { get; set; }
    public string Address { get; set; } = string.Empty;
}
