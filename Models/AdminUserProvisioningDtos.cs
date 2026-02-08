using System.Text.Json.Serialization;

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
    [JsonPropertyName("userId")]
    public string UserId { get; set; } = string.Empty;

    [JsonPropertyName("username")]
    public string Username { get; set; } = string.Empty;

    [JsonPropertyName("email")]
    public string Email { get; set; } = string.Empty;

    [JsonPropertyName("firstName")]
    public string? FirstName { get; set; }

    [JsonPropertyName("lastName")]
    public string? LastName { get; set; }

    [JsonPropertyName("roles")]
    public List<string> Roles { get; set; } = new();

    [JsonPropertyName("isDisabled")]
    public bool? IsDisabled { get; set; }

    [JsonPropertyName("createdAtUtc")]
    public DateTime? CreatedAtUtc { get; set; }

    [JsonPropertyName("modifiedAtUtc")]
    public DateTime? ModifiedAtUtc { get; set; }
}
