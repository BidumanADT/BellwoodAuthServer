using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;

namespace BellwoodAuthServer.Controllers;

/// <summary>
/// Admin endpoints for managing driver and affiliate users.
/// PHASE 2: Protected with AdminOnly authorization policy.
/// </summary>
[ApiController]
[Route("api/admin/users")]
[Authorize(Policy = "AdminOnly")] // PHASE 2: Require admin role for all endpoints
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
    /// Gets all users in the system with their roles and details.
    /// PHASE 2: Admin-only endpoint for user management interface.
    /// </summary>
    /// <param name="role">Optional: Filter by role (admin, dispatcher, booker, driver)</param>
    /// <param name="includeInactive">Optional: Include inactive/disabled users (default: false)</param>
    [HttpGet]
    public async Task<IActionResult> GetAllUsers(
        [FromQuery] string? role = null,
        [FromQuery] bool includeInactive = false)
    {
        // Get all users
        var allUsers = _userManager.Users.ToList();
        var result = new List<UserInfo>();

        foreach (var user in allUsers)
        {
            // Skip inactive users unless explicitly requested
            if (!includeInactive && user.LockoutEnabled && user.LockoutEnd.HasValue && user.LockoutEnd.Value > DateTimeOffset.UtcNow)
            {
                continue;
            }

            var roles = await _userManager.GetRolesAsync(user);
            var claims = await _userManager.GetClaimsAsync(user);
            var emailClaim = claims.FirstOrDefault(c => c.Type == "email");

            // Get primary role (mutually exclusive strategy means users have one role)
            var userRole = roles.FirstOrDefault() ?? "none";

            // Apply role filter if specified
            if (!string.IsNullOrWhiteSpace(role) && !userRole.Equals(role, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            // Determine if user is active
            var isActive = !user.LockoutEnabled || 
                          !user.LockoutEnd.HasValue || 
                          user.LockoutEnd.Value <= DateTimeOffset.UtcNow;

            // Get last login from security stamp (approximate - ASP.NET Identity doesn't track this by default)
            // For now, we'll use a placeholder. In production, you'd need to implement login tracking.
            DateTime? lastLogin = null;

            result.Add(new UserInfo
            {
                Username = user.UserName!,
                UserId = user.Id,
                Email = emailClaim?.Value ?? user.Email ?? "",
                Role = userRole,
                IsActive = isActive,
                CreatedAt = DateTime.UtcNow, // Placeholder - ASP.NET Identity doesn't store creation date by default
                LastLogin = lastLogin
            });
        }

        // Sort by username for consistent ordering
        result = result.OrderBy(u => u.Username).ToList();

        return Ok(result);
    }

    /// <summary>
    /// Gets a user by their uid claim value.
    /// </summary>
    [HttpGet("by-uid/{userUid}")]
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

/// <summary>
/// User information for admin user management interface.
/// PHASE 2: Used by GET /api/admin/users endpoint.
/// </summary>
public class UserInfo
{
    /// <summary>
    /// Username used for login.
    /// </summary>
    public string Username { get; set; } = "";

    /// <summary>
    /// Unique user identifier (Identity GUID).
    /// </summary>
    public string UserId { get; set; } = "";

    /// <summary>
    /// User's email address.
    /// </summary>
    public string Email { get; set; } = "";

    /// <summary>
    /// User's primary role (mutually exclusive strategy).
    /// </summary>
    public string Role { get; set; } = "";

    /// <summary>
    /// Whether the user account is currently active.
    /// </summary>
    public bool IsActive { get; set; } = true;

    /// <summary>
    /// When the user account was created.
    /// Note: ASP.NET Identity doesn't track this by default - placeholder value used.
    /// </summary>
    public DateTime CreatedAt { get; set; }

    /// <summary>
    /// Last login timestamp.
    /// Note: ASP.NET Identity doesn't track this by default - returns null.
    /// Implement login tracking middleware for accurate values.
    /// </summary>
    public DateTime? LastLogin { get; set; }
}
