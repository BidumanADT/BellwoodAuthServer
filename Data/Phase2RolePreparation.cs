using Microsoft.AspNetCore.Identity;

namespace BellwoodAuthServer.Data;

/// <summary>
/// Phase 2 role preparation - Ready to activate when Phase 2 begins.
/// Contains role seeding and user setup for dispatcher functionality.
/// </summary>
public static class Phase2RolePreparation
{
    /// <summary>
    /// Seeds the dispatcher role and creates a test dispatcher user.
    /// ACTIVATION: Uncomment the call to this method in Program.cs when starting Phase 2.
    /// </summary>
    public static async Task SeedDispatcherRole(RoleManager<IdentityRole> roleManager, UserManager<IdentityUser> userManager)
    {
        // Create dispatcher role if it doesn't exist
        if (!await roleManager.RoleExistsAsync("dispatcher"))
        {
            var result = await roleManager.CreateAsync(new IdentityRole("dispatcher"));
            if (!result.Succeeded)
            {
                throw new InvalidOperationException($"Failed to create dispatcher role: {string.Join(", ", result.Errors.Select(e => e.Description))}");
            }
        }

        // Create test dispatcher user "diana"
        var dispatcherUser = await userManager.FindByNameAsync("diana");
        if (dispatcherUser is null)
        {
            dispatcherUser = new IdentityUser 
            { 
                UserName = "diana",
                Email = "diana.dispatcher@bellwood.example",
                EmailConfirmed = true
            };
            var createResult = await userManager.CreateAsync(dispatcherUser, "password");
            if (!createResult.Succeeded)
            {
                throw new InvalidOperationException($"Failed to create dispatcher user: {string.Join(", ", createResult.Errors.Select(e => e.Description))}");
            }
        }

        // Ensure dispatcher user has the dispatcher role
        var roles = await userManager.GetRolesAsync(dispatcherUser);
        if (!roles.Contains("dispatcher"))
        {
            await userManager.AddToRoleAsync(dispatcherUser, "dispatcher");
        }

        // Ensure dispatcher user has email claim
        var claims = await userManager.GetClaimsAsync(dispatcherUser);
        var emailClaim = claims.FirstOrDefault(c => c.Type == "email");
        if (emailClaim == null && !string.IsNullOrEmpty(dispatcherUser.Email))
        {
            await userManager.AddClaimAsync(dispatcherUser, new System.Security.Claims.Claim("email", dispatcherUser.Email));
        }
    }

    /// <summary>
    /// Assigns the dispatcher role to an existing user.
    /// Useful for converting admin users to dispatchers when Phase 2 activates.
    /// </summary>
    public static async Task AssignDispatcherRole(string username, UserManager<IdentityUser> userManager, RoleManager<IdentityRole> roleManager)
    {
        // Ensure role exists
        if (!await roleManager.RoleExistsAsync("dispatcher"))
        {
            await roleManager.CreateAsync(new IdentityRole("dispatcher"));
        }

        var user = await userManager.FindByNameAsync(username);
        if (user == null)
        {
            throw new InvalidOperationException($"User '{username}' not found.");
        }

        var roles = await userManager.GetRolesAsync(user);
        if (!roles.Contains("dispatcher"))
        {
            await userManager.AddToRoleAsync(user, "dispatcher");
        }
    }
}
