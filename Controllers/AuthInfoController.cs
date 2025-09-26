using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace BellwoodAuthServer.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthInfoController : ControllerBase
{
    // GET /api/auth/me  (requires Bearer token)
    [HttpGet("me")]
    [Authorize]
    public IActionResult Me()
    {
        var claims = User.Claims.Select(c => new { c.Type, c.Value }).ToList();
        return Ok(new
        {
            user = User.Identity?.Name ?? User.FindFirstValue("sub"),
            claims
        });
    }
}
