using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BellwoodAuthServer.Models;

namespace BellwoodAuthServer.Controllers;

[ApiController]
[Route("api/admin/users")]  // Primary route - standardized
[Route("api/admin/provisioning")]  // Legacy route - backward compatibility
[Authorize(Policy = "AdminOnly")]
public class AdminUserProvisioningController : ControllerBase
{
    private static readonly string[] AllowedRoles = { "admin", "dispatcher", "booker", "driver" };

    private readonly UserManager<IdentityUser> _userManager;
    private readonly RoleManager<IdentityRole> _roleManager;

    public AdminUserProvisioningController(UserManager<IdentityUser> userManager, RoleManager<IdentityRole> roleManager)
    {
        _userManager = userManager;
        _roleManager = roleManager;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<UserSummaryDto>>> GetUsers([FromQuery] int take = 50, [FromQuery] int skip = 0)
    {
        if (take <= 0)
        {
            take = 50;
        }

        if (skip < 0)
        {
            skip = 0;
        }

        var users = await _userManager.Users
            .OrderBy(user => user.Email ?? user.UserName)
            .Skip(skip)
            .Take(take)
            .ToListAsync();

        var results = new List<UserSummaryDto>(users.Count);
        foreach (var user in users)
        {
            results.Add(await BuildSummaryAsync(user));
        }

        return Ok(results);
    }

    [HttpPost]
    public async Task<ActionResult<UserSummaryDto>> CreateUser([FromBody] CreateUserRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email))
        {
            return BadRequest(new { error = "Email is required." });
        }

        if (string.IsNullOrWhiteSpace(request.TempPassword))
        {
            return BadRequest(new { error = "TempPassword is required." });
        }

        var normalizedRoles = NormalizeRoles(request.Roles);
        var invalidRoles = normalizedRoles.Except(AllowedRoles, StringComparer.OrdinalIgnoreCase).ToList();
        if (invalidRoles.Count > 0)
        {
            return BadRequest(new { error = "Invalid roles requested.", roles = invalidRoles });
        }

        var existingUser = await _userManager.FindByEmailAsync(request.Email);
        if (existingUser != null)
        {
            return Conflict(new { error = "Email already exists." });
        }

        var existingByName = await _userManager.FindByNameAsync(request.Email);
        if (existingByName != null)
        {
            return Conflict(new { error = "Username already exists." });
        }

        var user = new IdentityUser
        {
            UserName = request.Email,
            Email = request.Email,
            EmailConfirmed = true  // Auto-confirm for admin-created users
        };

        var createResult = await _userManager.CreateAsync(user, request.TempPassword);
        if (!createResult.Succeeded)
        {
            return BadRequest(new { error = "Failed to create user.", details = createResult.Errors.Select(e => e.Description) });
        }

        await EnsureRolesExistAsync(normalizedRoles);

        if (normalizedRoles.Count > 0)
        {
            var addRolesResult = await _userManager.AddToRolesAsync(user, normalizedRoles);
            if (!addRolesResult.Succeeded)
            {
                return BadRequest(new { error = "Failed to assign roles.", details = addRolesResult.Errors.Select(e => e.Description) });
            }
        }

        return Ok(await BuildSummaryAsync(user));
    }

    [HttpPut("{userId}/roles")]
    public async Task<ActionResult<UserSummaryDto>> UpdateRoles(string userId, [FromBody] UpdateRolesRequest request)
    {
        var user = await _userManager.FindByIdAsync(userId);
        if (user == null)
        {
            return NotFound(new { error = "User not found." });
        }

        var normalizedRoles = NormalizeRoles(request.Roles);
        var invalidRoles = normalizedRoles.Except(AllowedRoles, StringComparer.OrdinalIgnoreCase).ToList();
        if (invalidRoles.Count > 0)
        {
            return BadRequest(new { error = "Invalid roles requested.", roles = invalidRoles });
        }

        var existingRoles = await _userManager.GetRolesAsync(user);
        if (existingRoles.Count > 0)
        {
            var removeResult = await _userManager.RemoveFromRolesAsync(user, existingRoles);
            if (!removeResult.Succeeded)
            {
                return BadRequest(new { error = "Failed to remove existing roles.", details = removeResult.Errors.Select(e => e.Description) });
            }
        }

        await EnsureRolesExistAsync(normalizedRoles);

        if (normalizedRoles.Count > 0)
        {
            var addResult = await _userManager.AddToRolesAsync(user, normalizedRoles);
            if (!addResult.Succeeded)
            {
                return BadRequest(new { error = "Failed to assign roles.", details = addResult.Errors.Select(e => e.Description) });
            }
        }

        return Ok(await BuildSummaryAsync(user));
    }

    [HttpPut("{userId}/disable")]
    public async Task<ActionResult<UserSummaryDto>> DisableUser(string userId)
    {
        var user = await _userManager.FindByIdAsync(userId);
        if (user == null)
        {
            return NotFound(new { error = "User not found." });
        }

        user.LockoutEnabled = true;
        user.LockoutEnd = DateTimeOffset.UtcNow.AddYears(100);

        var updateResult = await _userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return BadRequest(new { error = "Failed to disable user.", details = updateResult.Errors.Select(e => e.Description) });
        }

        return Ok(await BuildSummaryAsync(user));
    }

    /// <summary>
    /// Re-enables a disabled user account.
    /// </summary>
    [HttpPut("{userId}/enable")]
    public async Task<ActionResult<UserSummaryDto>> EnableUser(string userId)
    {
        var user = await _userManager.FindByIdAsync(userId);
        if (user == null)
        {
            return NotFound(new { error = "User not found." });
        }

        // Remove lockout
        user.LockoutEnabled = false;
        user.LockoutEnd = null;

        var updateResult = await _userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return BadRequest(new 
            { 
                error = "Failed to enable user.", 
                details = updateResult.Errors.Select(e => e.Description) 
            });
        }

        return Ok(await BuildSummaryAsync(user));
    }

    private static List<string> NormalizeRoles(IEnumerable<string>? roles)
    {
        return roles
            ?.Where(role => !string.IsNullOrWhiteSpace(role))
            .Select(role => role.Trim().ToLowerInvariant())
            .Distinct()
            .ToList() ?? new List<string>();
    }

    private async Task EnsureRolesExistAsync(IEnumerable<string> roles)
    {
        foreach (var role in roles)
        {
            // Normalize role to lowercase
            var normalizedRole = role.ToLowerInvariant();
            
            if (!await _roleManager.RoleExistsAsync(normalizedRole))
            {
                await _roleManager.CreateAsync(new IdentityRole(normalizedRole));
            }
        }
    }

    private async Task<UserSummaryDto> BuildSummaryAsync(IdentityUser user)
    {
        var roles = await _userManager.GetRolesAsync(user);
        var isDisabled = user.LockoutEnabled && user.LockoutEnd.HasValue && user.LockoutEnd.Value > DateTimeOffset.UtcNow;

        return new UserSummaryDto
        {
            UserId = user.Id,
            Username = user.UserName ?? string.Empty,  // Added - AdminPortal needs this
            Email = user.Email ?? string.Empty,
            FirstName = null,
            LastName = null,
            Roles = roles.Select(r => r.ToLowerInvariant()).ToList(), // Always return normalized roles
            IsDisabled = isDisabled,
            CreatedAtUtc = null,
            ModifiedAtUtc = null
        };
    }
}
