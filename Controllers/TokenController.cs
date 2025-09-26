using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace BellwoodAuthServer.Controllers;

[ApiController]
public class TokenController : ControllerBase
{
    private readonly UserManager<IdentityUser> _users;
    private readonly IConfiguration _config;

    public TokenController(UserManager<IdentityUser> users, IConfiguration config)
    {
        _users = users;
        _config = config;
    }

    // POST /connect/token (x-www-form-urlencoded)
    // grant_type=password&client_id=bellwood-maui-dev&username=alice&password=password&scope=api.rides offline_access
    [HttpPost("/connect/token")]
    [AllowAnonymous]
    public async Task<IActionResult> Token([FromForm] TokenRequest req)
    {
        if (!string.Equals(req.grant_type, "password", StringComparison.OrdinalIgnoreCase))
            return BadRequest(new { error = "unsupported_grant_type" });

        // (Optional) simple client_id check in dev; relax/remove if not needed
        if (!string.IsNullOrWhiteSpace(req.client_id) &&
            !string.Equals(req.client_id, "bellwood-maui-dev", StringComparison.Ordinal))
        {
            return Unauthorized(new { error = "invalid_client" });
        }

        var user = await _users.FindByNameAsync(req.username ?? "");
        if (user is null || !(await _users.CheckPasswordAsync(user, req.password ?? "")))
            return Unauthorized(new { error = "invalid_grant" });

        // Issue JWT (same signing key you use in Rides API)
        var keyStr = _config["Jwt:Key"] ?? "super-long-jwt-signing-secret-1234";
        var creds = new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(keyStr)), SecurityAlgorithms.HmacSha256);

        var claims = new List<Claim>
        {
            new("sub", user.UserName!),
            new("uid", user.Id),
            // include requested scope if you want
            new("scope", string.IsNullOrWhiteSpace(req.scope) ? "api.rides offline_access" : req.scope!)
        };

        var expires = DateTime.UtcNow.AddHours(1);
        var jwt = new JwtSecurityToken(claims: claims, expires: expires, signingCredentials: creds);
        var token = new JwtSecurityTokenHandler().WriteToken(jwt);

        return Ok(new
        {
            access_token = token,
            token_type = "Bearer",
            expires_in = (int)TimeSpan.FromHours(1).TotalSeconds,
            scope = string.IsNullOrWhiteSpace(req.scope) ? "api.rides offline_access" : req.scope
            // refresh_token = "dev-placeholder" // add when you implement refresh
        });
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
