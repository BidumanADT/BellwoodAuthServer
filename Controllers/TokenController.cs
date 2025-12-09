using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using BellwoodAuthServer.Services;

namespace BellwoodAuthServer.Controllers;

[ApiController]
public class TokenController : ControllerBase
{
    private readonly UserManager<IdentityUser> _users;
    private readonly IConfiguration _config;
    private readonly RefreshTokenStore _store;

    public TokenController(UserManager<IdentityUser> users, IConfiguration config, RefreshTokenStore store)
    {
        _users = users;
        _config = config;
        _store = store;
    }

    [HttpPost("/connect/token")]
    [AllowAnonymous]
    public async Task<IActionResult> Token([FromForm] TokenRequest req)
    {
        var keyStr = _config["Jwt:Key"] ?? "super-long-jwt-signing-secret-1234";
        var creds = new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(keyStr)), SecurityAlgorithms.HmacSha256);

        if (string.Equals(req.grant_type, "password", StringComparison.OrdinalIgnoreCase))
        {
            if (!string.IsNullOrWhiteSpace(req.client_id) &&
                !string.Equals(req.client_id, "bellwood-maui-dev", StringComparison.Ordinal))
                return Unauthorized(new { error = "invalid_client" });

            var user = await _users.FindByNameAsync(req.username ?? "");
            if (user is null || !(await _users.CheckPasswordAsync(user, req.password ?? "")))
                return Unauthorized(new { error = "invalid_grant" });

            var (access, refresh) = await IssueTokensAsync(user, req.scope, creds);
            return Ok(new
            {
                access_token = access,
                token_type = "Bearer",
                expires_in = 3600,
                scope = string.IsNullOrWhiteSpace(req.scope) ? "api.rides offline_access" : req.scope,
                refresh_token = refresh
            });
        }

        if (string.Equals(req.grant_type, "refresh_token", StringComparison.OrdinalIgnoreCase))
        {
            if (string.IsNullOrWhiteSpace(req.refresh_token))
                return BadRequest(new { error = "invalid_request" });

            if (!_store.TryRedeem(req.refresh_token, out var username))
                return Unauthorized(new { error = "invalid_grant" });

            var user = await _users.FindByNameAsync(username);
            if (user is null) return Unauthorized(new { error = "invalid_grant" });

            var (access, refresh) = await IssueTokensAsync(user, req.scope, creds); // rotate RT
            return Ok(new
            {
                access_token = access,
                token_type = "Bearer",
                expires_in = 3600,
                scope = string.IsNullOrWhiteSpace(req.scope) ? "api.rides offline_access" : req.scope,
                refresh_token = refresh
            });
        }

        return BadRequest(new { error = "unsupported_grant_type" });
    }

    private async Task<(string access, string refresh)> IssueTokensAsync(IdentityUser user, string? scope, SigningCredentials creds)
    {
        var claims = new List<Claim> {
            new("sub", user.UserName!),
            new("uid", user.Id),
            new("scope", string.IsNullOrWhiteSpace(scope) ? "api.rides offline_access" : scope!)
        };
        
        // Add role claims
        var roles = await _users.GetRolesAsync(user);
        foreach (var role in roles)
        {
            claims.Add(new Claim("role", role));
        }
        
        // Add custom uid claim if exists (overrides default user.Id)
        var userClaims = await _users.GetClaimsAsync(user);
        var customUid = userClaims.FirstOrDefault(c => c.Type == "uid");
        if (customUid != null)
        {
            claims.RemoveAll(c => c.Type == "uid");
            claims.Add(customUid);
        }
        
        var jwt = new JwtSecurityToken(claims: claims, expires: DateTime.UtcNow.AddHours(1), signingCredentials: creds);
        var access = new JwtSecurityTokenHandler().WriteToken(jwt);

        var refresh = _store.Issue(user.UserName!);
        return (access, refresh);
    }

    public class TokenRequest
    {
        public string? grant_type { get; set; }
        public string? client_id { get; set; }
        public string? username { get; set; }
        public string? password { get; set; }
        public string? scope { get; set; }
        public string? refresh_token { get; set; }
    }
}
