namespace BellwoodAuthServer.Models;

public class CreateUserRequest
{
    public string Email { get; set; } = string.Empty;
    public string? FirstName { get; set; }
    public string? LastName { get; set; }
    public string TempPassword { get; set; } = string.Empty;
    public List<string> Roles { get; set; } = new();
}

public class UpdateRolesRequest
{
    public List<string> Roles { get; set; } = new();
}

public class UserSummaryDto
{
    public string UserId { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? FirstName { get; set; }
    public string? LastName { get; set; }
    public List<string> Roles { get; set; } = new();
    public bool? IsDisabled { get; set; }
    public DateTime? CreatedAtUtc { get; set; }
    public DateTime? ModifiedAtUtc { get; set; }
}
