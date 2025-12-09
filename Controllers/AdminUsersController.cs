using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;

namespace BellwoodAuthServer.Controllers;

/// <summary>
/// Admin endpoints for managing driver and affiliate users.
/// In production, these endpoints should be protected with admin authorization.
/// </summary>
[ApiController]
[Route("api/admin/users")]
public class AdminUsersController : ControllerBase
{
    private readonly UserManager<IdentityUser> _userManager;
    private readonly RoleManager<IdentityRole> _roleManager;

    public AdminUsersController(UserManager<IdentityUser> userManager, RoleManager<IdentityRole> roleManager)
    {
        _userManager = userManager;
        _roleManager = roleManager;
    }

    /// <summary>
    /// Creates a new driver user with the specified uid claim.
    /// The uid should match the UserUid set on the Driver record in AdminAPI.
    /// </summary>
    [HttpPost("drivers")]
    [AllowAnonymous] // TODO: In production, restrict to admin role
    public async Task<IActionResult> CreateDriverUser([FromBody] CreateDriverUserRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Username))
            return BadRequest(new { error = "Username is required." });

        if (string.IsNullOrWhiteSpace(request.Password))
            return BadRequest(new { error = "Password is required." });

        if (string.IsNullOrWhiteSpace(request.UserUid))
            return BadRequest(new { error = "UserUid is required. This should match the driver's UserUid in AdminAPI." });

        // Check if username already exists
        var existingUser = await _userManager.FindByNameAsync(request.Username);
        if (existingUser != null)
            return Conflict(new { error = $"Username '{request.Username}' already exists." });

        // Check if uid claim is already in use
        var allUsers = _userManager.Users.ToList();
        foreach (var u in allUsers)
        {
            var claims = await _userManager.GetClaimsAsync(u);
            if (claims.Any(c => c.Type == "uid" && c.Value == request.UserUid))
            {
                return Conflict(new { error = $"UserUid '{request.UserUid}' is already assigned to another user." });
            }
        }

        // Ensure driver role exists
        if (!await _roleManager.RoleExistsAsync("driver"))
        {
            await _roleManager.CreateAsync(new IdentityRole("driver"));
        }

        // Create the user
        var user = new IdentityUser { UserName = request.Username };
        var createResult = await _userManager.CreateAsync(user, request.Password);
        if (!createResult.Succeeded)
        {
            return BadRequest(new { error = "Failed to create user.", details = createResult.Errors.Select(e => e.Description) });
        }

        // Add driver role
        await _userManager.AddToRoleAsync(user, "driver");

        // Add custom uid claim
        await _userManager.AddClaimAsync(user, new Claim("uid", request.UserUid));

        return Ok(new
        {
            message = "Driver user created successfully.",
            userId = user.Id,
            username = user.UserName,
            userUid = request.UserUid,
            role = "driver"
        });
    }

    /// <summary>
    /// Updates the uid claim for an existing user.
    /// </summary>
    [HttpPut("{username}/uid")]
    [AllowAnonymous] // TODO: In production, restrict to admin role
    public async Task<IActionResult> UpdateUserUid(string username, [FromBody] UpdateUserUidRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.UserUid))
            return BadRequest(new { error = "UserUid is required." });

        var user = await _userManager.FindByNameAsync(username);
        if (user == null)
            return NotFound(new { error = $"User '{username}' not found." });

        // Check if uid claim is already in use by another user
        var allUsers = _userManager.Users.ToList();
        foreach (var u in allUsers)
        {
            if (u.Id == user.Id) continue; // Skip current user

            var claims = await _userManager.GetClaimsAsync(u);
            if (claims.Any(c => c.Type == "uid" && c.Value == request.UserUid))
            {
                return Conflict(new { error = $"UserUid '{request.UserUid}' is already assigned to another user." });
            }
        }

        // Remove existing uid claim if present
        var existingClaims = await _userManager.GetClaimsAsync(user);
        var existingUidClaim = existingClaims.FirstOrDefault(c => c.Type == "uid");
        if (existingUidClaim != null)
        {
            await _userManager.RemoveClaimAsync(user, existingUidClaim);
        }

        // Add new uid claim
        await _userManager.AddClaimAsync(user, new Claim("uid", request.UserUid));

        return Ok(new
        {
            message = "UserUid updated successfully.",
            username = user.UserName,
            userUid = request.UserUid
        });
    }

    /// <summary>
    /// Gets all users with the driver role.
    /// </summary>
    [HttpGet("drivers")]
    [AllowAnonymous] // TODO: In production, restrict to admin role
    public async Task<IActionResult> GetDriverUsers()
    {
        var driversInRole = await _userManager.GetUsersInRoleAsync("driver");
        var result = new List<DriverUserInfo>();

        foreach (var user in driversInRole)
        {
            var claims = await _userManager.GetClaimsAsync(user);
            var uidClaim = claims.FirstOrDefault(c => c.Type == "uid");

            result.Add(new DriverUserInfo
            {
                UserId = user.Id,
                Username = user.UserName!,
                UserUid = uidClaim?.Value
            });
        }

        return Ok(result);
    }

    /// <summary>
    /// Gets a user by their uid claim value.
    /// </summary>
    [HttpGet("by-uid/{userUid}")]
    [AllowAnonymous] // TODO: In production, restrict to admin role
    public async Task<IActionResult> GetUserByUid(string userUid)
    {
        var allUsers = _userManager.Users.ToList();
        foreach (var user in allUsers)
        {
            var claims = await _userManager.GetClaimsAsync(user);
            var uidClaim = claims.FirstOrDefault(c => c.Type == "uid" && c.Value == userUid);
            if (uidClaim != null)
            {
                var roles = await _userManager.GetRolesAsync(user);
                return Ok(new
                {
                    userId = user.Id,
                    username = user.UserName,
                    userUid = uidClaim.Value,
                    roles = roles
                });
            }
        }

        return NotFound(new { error = $"No user found with uid '{userUid}'." });
    }

    /// <summary>
    /// Deletes a driver user by username.
    /// </summary>
    [HttpDelete("drivers/{username}")]
    [AllowAnonymous] // TODO: In production, restrict to admin role
    public async Task<IActionResult> DeleteDriverUser(string username)
    {
        var user = await _userManager.FindByNameAsync(username);
        if (user == null)
            return NotFound(new { error = $"User '{username}' not found." });

        var result = await _userManager.DeleteAsync(user);
        if (!result.Succeeded)
        {
            return BadRequest(new { error = "Failed to delete user.", details = result.Errors.Select(e => e.Description) });
        }

        return Ok(new { message = $"User '{username}' deleted successfully." });
    }
}

public class CreateDriverUserRequest
{
    /// <summary>
    /// The login username for the driver.
    /// </summary>
    public string Username { get; set; } = "";

    /// <summary>
    /// The login password for the driver.
    /// </summary>
    public string Password { get; set; } = "";

    /// <summary>
    /// The unique identifier that links to the Driver record in AdminAPI.
    /// This should match the Driver.UserUid field.
    /// </summary>
    public string UserUid { get; set; } = "";
}

public class UpdateUserUidRequest
{
    /// <summary>
    /// The new UserUid value to assign to the user.
    /// </summary>
    public string UserUid { get; set; } = "";
}

public class DriverUserInfo
{
    public string UserId { get; set; } = "";
    public string Username { get; set; } = "";
    public string? UserUid { get; set; }
}
