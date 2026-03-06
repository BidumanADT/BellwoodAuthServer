using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using BellwoodAuthServer.Data;
using BellwoodAuthServer.Services;
using BellwoodAuthServer.Options;
using BellwoodAuthServer.Middleware;
using Serilog;
using Serilog.Context;

var builder = WebApplication.CreateBuilder(args);

Log.Logger = new LoggerConfiguration()
    .Enrich.FromLogContext()
    .Enrich.WithProperty("service", "AuthServer")
    .Enrich.WithProperty("environment", "Alpha")
    .WriteTo.Console()
    .CreateLogger();

builder.Host.UseSerilog();

builder.Services.Configure<EmailOptions>(builder.Configuration.GetSection("Email"));

var configuredDbPath = builder.Configuration["AuthServer:DbPath"];
var resolvedDbPath = string.IsNullOrWhiteSpace(configuredDbPath)
    ? Path.Combine(AppContext.BaseDirectory, "App_Data", "authserver", "alpha.db")
    : configuredDbPath;

if (!Path.IsPathRooted(resolvedDbPath))
{
    resolvedDbPath = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, resolvedDbPath));
}

var resolvedDbDirectory = Path.GetDirectoryName(resolvedDbPath);
if (!string.IsNullOrWhiteSpace(resolvedDbDirectory))
{
    Directory.CreateDirectory(resolvedDbDirectory);
}

builder.Configuration["ConnectionStrings:DefaultConnection"] = $"Data Source={resolvedDbPath}";
Log.Information("Resolved AuthServer SQLite path: {DbPath}", resolvedDbPath);

// Bind to ports in local dev only.
// In non-Development (ECS, etc.) ASPNETCORE_URLS / port bindings come from the container host.
if (builder.Environment.IsDevelopment())
{
    builder.WebHost.UseUrls("https://localhost:5001", "http://localhost:5000");
}

// EF Core + Identity (SQLite)
builder.Services.AddDbContext<ApplicationDbContext>(opt =>
    opt.UseSqlite(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services
    .AddIdentityCore<IdentityUser>(o =>
    {
        o.Password.RequireNonAlphanumeric = false;
        o.Password.RequireUppercase = false;
        o.Password.RequireLowercase = false;
        o.Password.RequireDigit = false;
        o.Password.RequiredLength = 6;
    })
    .AddRoles<IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddSignInManager();

// JWT signing key — loaded from configuration (Jwt:Key).
/// In AWS ECS supply via the Jwt__Key environment variable (double-underscore = colon in .NET config).
/// In local dev, set Jwt:Key in appsettings.Development.json or user-secrets (never commit the key).
var jwtKeyValue = builder.Configuration["Jwt:Key"];

if (string.IsNullOrWhiteSpace(jwtKeyValue))
{
    if (builder.Environment.IsDevelopment())
    {
        // Allow dev to keep running with the legacy fallback so existing local setups don't break.
        jwtKeyValue = "super-long-jwt-signing-secret-1234";
        Log.Warning("JWT: Jwt:Key not configured — using insecure development fallback. " +
                    "Set Jwt:Key in appsettings.Development.json or user-secrets before sharing tokens.");
    }
    else
    {
        // Hard fail in any non-Development environment: a missing key is a misconfiguration, not a warning.
        Log.Fatal("JWT: Jwt:Key is not configured. " +
                  "Set the Jwt__Key environment variable (ECS task definition / Secrets Manager) before starting. Aborting.");
        throw new InvalidOperationException(
            "Jwt:Key must be configured in non-Development environments. " +
            "Set the Jwt__Key environment variable.");
    }
}

Log.Information("JWT: Signing key loaded from configuration ({Source}).",
    builder.Configuration["Jwt:Key"] is not null ? "Jwt:Key" : "dev-fallback");

var key  = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKeyValue));
var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256;

builder.Services
  .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
  .AddJwtBearer(o =>
  {
      o.TokenValidationParameters = new TokenValidationParameters
      {
          ValidateIssuer = false,
          ValidateAudience = false,
          ValidateLifetime = true,
          IssuerSigningKey = key,
          ClockSkew = TimeSpan.Zero
      };
  });

// PHASE 2: Authorization policies for role-based access control
builder.Services.AddAuthorization(options =>
{
    // AdminOnly: Requires admin role
    // Use for: User management, role assignment, sensitive operations
    options.AddPolicy("AdminOnly", policy =>
        policy.RequireRole("admin"));
    
    // StaffOnly: Requires admin OR dispatcher role
    // Use for: Operational endpoints accessible to both admins and dispatchers
    options.AddPolicy("StaffOnly", policy =>
        policy.RequireRole("admin", "dispatcher"));
    
    // DriverOnly: Requires driver role (already used in AdminAPI)
    // Included here for completeness
    options.AddPolicy("DriverOnly", policy =>
        policy.RequireRole("driver"));
    
    // BookerOnly: Requires booker role
    // Use for: Passenger-specific endpoints
    options.AddPolicy("BookerOnly", policy =>
        policy.RequireRole("booker"));
});

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddSingleton<RefreshTokenStore>();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<AuthAuditService>();
builder.Services.AddTransient<CorrelationHeaderHandler>();
builder.Services.AddSingleton(new SigningKeyState { IsLoaded = key.Key?.Length > 0 });
builder.Services.AddHttpClient("default").AddHttpMessageHandler<CorrelationHeaderHandler>();

var app = builder.Build();

// Auto-migrate and seed users
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

    // Log the resolved connection string so that relative-path confusion is visible in logs.
    var connString = db.Database.GetConnectionString();
    Log.Information("DB: {ConnectionString}", connString);

    // Apply any pending Entity Framework migrations.
    await db.Database.MigrateAsync();

    // Ensure that critical tables exist even if a prior migration was empty or skipped.
    BellwoodAuthServer.Data.AuthSchemaInitializer.EnsureAuditTableExists(db);

    var um = scope.ServiceProvider.GetRequiredService<UserManager<IdentityUser>>();
    var rm = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole>>();

    // Create roles if they don't exist (all environments)
    foreach (var roleName in new[] { "admin", "booker", "driver", "dispatcher" })
    {
        if (!await rm.RoleExistsAsync(roleName))
            await rm.CreateAsync(new IdentityRole(roleName));
    }

    if (app.Environment.IsDevelopment())
    {
        // Development only: seed convenience test users (alice, bob, chris, charlie, diana, etc.)
        async Task EnsureUser(string user, string pw)
        {
            if (await um.FindByNameAsync(user) is null)
                await um.CreateAsync(new IdentityUser { UserName = user }, pw);
        }
        await EnsureUser("alice", "password");
        await EnsureUser("bob", "password");

        // Add admin role to alice and bob
        var alice = await um.FindByNameAsync("alice");
        if (alice != null)
        {
            if (string.IsNullOrEmpty(alice.Email))
            {
                alice.Email = "alice.admin@bellwood.example";
                alice.EmailConfirmed = true;
                await um.UpdateAsync(alice);
            }

            var aliceRoles = await um.GetRolesAsync(alice);
            if (!aliceRoles.Contains("admin"))
                await um.AddToRoleAsync(alice, "admin");

            var aliceClaims = await um.GetClaimsAsync(alice);
            if (!aliceClaims.Any(c => c.Type == "email"))
                await um.AddClaimAsync(alice, new Claim("email", alice.Email));
        }

        var bob = await um.FindByNameAsync("bob");
        if (bob != null)
        {
            if (string.IsNullOrEmpty(bob.Email))
            {
                bob.Email = "bob.admin@bellwood.example";
                bob.EmailConfirmed = true;
                await um.UpdateAsync(bob);
            }

            var bobRoles = await um.GetRolesAsync(bob);
            if (!bobRoles.Contains("admin"))
                await um.AddToRoleAsync(bob, "admin");

            var bobClaims = await um.GetClaimsAsync(bob);
            if (!bobClaims.Any(c => c.Type == "email"))
                await um.AddClaimAsync(bob, new Claim("email", bob.Email));
        }

        // Create passenger test user with email claim
        var passengerUser = await um.FindByNameAsync("chris");
        if (passengerUser is null)
        {
            passengerUser = new IdentityUser
            {
                UserName = "chris",
                Email = "chris.bailey@example.com",
                EmailConfirmed = true
            };
            await um.CreateAsync(passengerUser, "password");
        }
        else
        {
            if (passengerUser.Email != "chris.bailey@example.com")
            {
                passengerUser.Email = "chris.bailey@example.com";
                passengerUser.EmailConfirmed = true;
                await um.UpdateAsync(passengerUser);
            }
        }

        var chrisRoles = await um.GetRolesAsync(passengerUser);
        if (!chrisRoles.Contains("booker"))
            await um.AddToRoleAsync(passengerUser, "booker");

        var chrisClaims = await um.GetClaimsAsync(passengerUser);
        var chrisEmailClaim = chrisClaims.FirstOrDefault(c => c.Type == "email");
        if (chrisEmailClaim == null)
            await um.AddClaimAsync(passengerUser, new Claim("email", "chris.bailey@example.com"));
        else if (chrisEmailClaim.Value != "chris.bailey@example.com")
        {
            await um.RemoveClaimAsync(passengerUser, chrisEmailClaim);
            await um.AddClaimAsync(passengerUser, new Claim("email", "chris.bailey@example.com"));
        }

        // Create driver test user with role and custom uid claim
        // Note: Using "driver-001" for backward compatibility with existing test data
        var driverUser = await um.FindByNameAsync("charlie");
        if (driverUser is null)
        {
            driverUser = new IdentityUser { UserName = "charlie" };
            await um.CreateAsync(driverUser, "password");
        }

        var charlieRoles = await um.GetRolesAsync(driverUser);
        if (!charlieRoles.Contains("driver"))
            await um.AddToRoleAsync(driverUser, "driver");

        var charlieClaims = await um.GetClaimsAsync(driverUser);
        var charlieUidClaim = charlieClaims.FirstOrDefault(c => c.Type == "uid");
        if (charlieUidClaim == null)
            await um.AddClaimAsync(driverUser, new Claim("uid", "driver-001"));
        else if (charlieUidClaim.Value != "driver-001")
        {
            await um.RemoveClaimAsync(driverUser, charlieUidClaim);
            await um.AddClaimAsync(driverUser, new Claim("uid", "driver-001"));
        }

        // Create additional test drivers with GUID-based UIDs for scalability testing
        async Task EnsureDriverUser(string username, string password, string userUid)
        {
            var user = await um.FindByNameAsync(username);
            if (user is null)
            {
                user = new IdentityUser { UserName = username };
                var result = await um.CreateAsync(user, password);
                if (result.Succeeded)
                {
                    await um.AddToRoleAsync(user, "driver");
                    await um.AddClaimAsync(user, new Claim("uid", userUid));
                }
            }
            else
            {
                var roles = await um.GetRolesAsync(user);
                if (!roles.Contains("driver"))
                    await um.AddToRoleAsync(user, "driver");

                var claims = await um.GetClaimsAsync(user);
                var uidClaim = claims.FirstOrDefault(c => c.Type == "uid");
                if (uidClaim == null)
                    await um.AddClaimAsync(user, new Claim("uid", userUid));
            }
        }

        await EnsureDriverUser("driver_dave", "password", Guid.NewGuid().ToString("N"));
        await EnsureDriverUser("driver_eve", "password", Guid.NewGuid().ToString("N"));

        // PHASE 2: Seed dispatcher test user (diana)
        await Phase2RolePreparation.SeedDispatcherRole(rm, um);
    }
    else
    {
        // Non-Development: create a single bootstrap admin if no admin user exists.
        // Credentials are NEVER hardcoded; they are read from config / environment variables.
        // Idempotent: if any admin already exists this block is a no-op.
        var adminUsers = await um.GetUsersInRoleAsync("admin");
        if (adminUsers.Count == 0)
        {
            var bootstrapEmail    = app.Configuration["BootstrapAdmin:Email"];
            var bootstrapPassword = app.Configuration["BootstrapAdmin:Password"];

            if (string.IsNullOrWhiteSpace(bootstrapEmail) || string.IsNullOrWhiteSpace(bootstrapPassword))
            {
                Log.Warning("STARTUP: No admin users exist and BootstrapAdmin:Email / BootstrapAdmin:Password " +
                            "are not configured. The system has no admin user. " +
                            "Set these via environment variables (BootstrapAdmin__Email, BootstrapAdmin__Password) " +
                            "or appsettings before starting.");
            }
            else
            {
                // FindByEmail first; fall back to FindByName in case email was used as username.
                var existing = await um.FindByEmailAsync(bootstrapEmail)
                             ?? await um.FindByNameAsync(bootstrapEmail);

                if (existing is null)
                {
                    var bootstrapUser = new IdentityUser
                    {
                        UserName       = bootstrapEmail,
                        Email          = bootstrapEmail,
                        EmailConfirmed = true
                    };
                    var result = await um.CreateAsync(bootstrapUser, bootstrapPassword);
                    if (result.Succeeded)
                    {
                        await um.AddToRoleAsync(bootstrapUser, "admin");
                        await um.AddClaimAsync(bootstrapUser, new Claim("email", bootstrapEmail));
                        Log.Information("STARTUP: Bootstrap admin created. Login with the configured email.");
                    }
                    else
                    {
                        Log.Error("STARTUP: Failed to create bootstrap admin: {Errors}",
                            string.Join(", ", result.Errors.Select(e => e.Description)));
                    }
                }
                else
                {
                    // User already exists (e.g. previous startup attempt) — ensure admin role.
                    if (!await um.IsInRoleAsync(existing, "admin"))
                        await um.AddToRoleAsync(existing, "admin");
                    Log.Information("STARTUP: Bootstrap admin already exists. Skipping creation.");
                }
            }
        }
        else
        {
            Log.Debug("STARTUP: Bootstrap admin step skipped — admin user(s) already exist.");
        }
    }
}

// Pipeline
app.UseSerilogRequestLogging();
app.UseMiddleware<CorrelationIdMiddleware>();
app.UseMiddleware<RequestLoggingMiddleware>();
app.UseHttpsRedirection();
app.UseSwagger();
app.UseSwaggerUI();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// JSON login endpoints (return access + refresh)
app.MapPost("/login", 
    async (
    UserManager<IdentityUser> um,
    SignInManager<IdentityUser> sm,
    RefreshTokenStore store,
    AuthAuditService auditService,
    HttpContext httpContext,
    LoginRequest? req) =>
{
    if (req is null)
    {
        return Results.BadRequest(new { error = "Request body missing." });
    }

    if (string.IsNullOrWhiteSpace(req.Username) ||
        string.IsNullOrWhiteSpace(req.Password))
    {
        return Results.BadRequest(new { error = "Username and password are required." });
    }

    var user = await um.FindByNameAsync(req.Username);
    if (user is null)
    {
        // don't leak whether the user exists
        await auditService.LogEventAsync(httpContext, req.Username, "login", "failure");
        return Results.Unauthorized();
    }

    // Check password and lockout status
    var signInResult = await sm.CheckPasswordSignInAsync(user, req.Password, lockoutOnFailure: false);
    
    if (signInResult.IsLockedOut)
    {
        return Results.Problem(
            detail: "User account is disabled.",
            statusCode: 403,
            title: "Account Disabled");
    }

    if (!signInResult.Succeeded)
    {
        // Password wrong or other issue
        await auditService.LogEventAsync(httpContext, req.Username, "login", "failure");
        return Results.Unauthorized();
    }

    var claims = new List<Claim>
    {
        new Claim("sub", user.UserName!),
        new Claim("uid", user.Id),
        new Claim("userId", user.Id)  // PHASE 1: Always Identity GUID for audit tracking
    };
    
    // Add role claims
    var roles = await um.GetRolesAsync(user);
    foreach (var role in roles)
    {
        claims.Add(new Claim("role", role));
    }
    
    // Add user claims (email, custom uid, etc.)
    var userClaims = await um.GetClaimsAsync(user);
    
    // Add email claim if exists
    var emailClaim = userClaims.FirstOrDefault(c => c.Type == "email");
    if (emailClaim != null)
    {
        claims.Add(emailClaim);
    }
    else if (!string.IsNullOrEmpty(user.Email))
    {
        // Fallback to user.Email if no email claim
        claims.Add(new Claim("email", user.Email));
    }
    
    // Add custom uid claim if exists (overrides default uid, userId remains Identity GUID)
    var customUid = userClaims.FirstOrDefault(c => c.Type == "uid");
    if (customUid != null)
    {
        claims.RemoveAll(c => c.Type == "uid");
        claims.Add(customUid);
        // Note: userId claim is NOT overridden - it always contains Identity GUID
    }

    await auditService.LogEventAsync(httpContext, user.UserName, "login", "success");


    var token = new System.IdentityModel.Tokens.Jwt.JwtSecurityToken(
        claims: claims,
        expires: DateTime.UtcNow.AddHours(1),
        signingCredentials: creds);

    var jwt = new System.IdentityModel.Tokens.Jwt.JwtSecurityTokenHandler().WriteToken(token);
    var refresh = store.Issue(user.UserName!);

    return Results.Ok(new
    {
        accessToken = jwt,
        refreshToken = refresh,
        access_token = jwt,
        refresh_token = refresh,
        token = jwt
    });
}).AllowAnonymous();

app.MapPost("/api/auth/login", 
    async (
    UserManager<IdentityUser> um,
    SignInManager<IdentityUser> sm,
    RefreshTokenStore store,
    AuthAuditService auditService,
    HttpContext httpContext,
    LoginRequest? req) =>
{
    if (req is null)
    {
        return Results.BadRequest(new { error = "Request body missing." });
    }

    if (string.IsNullOrWhiteSpace(req.Username) ||
        string.IsNullOrWhiteSpace(req.Password))
    {
        return Results.BadRequest(new { error = "Username and password are required." });
    }

    var user = await um.FindByNameAsync(req.Username);
    if (user is null)
    {
        await auditService.LogEventAsync(httpContext, req.Username, "login", "failure");
        return Results.Unauthorized();
    }

    // Check password and lockout status
    var signInResult = await sm.CheckPasswordSignInAsync(user, req.Password, lockoutOnFailure: false);
    
    if (signInResult.IsLockedOut)
    {
        return Results.Problem(
            detail: "User account is disabled.",
            statusCode: 403,
            title: "Account Disabled");
    }

    if (!signInResult.Succeeded)
    {
        await auditService.LogEventAsync(httpContext, req.Username, "login", "failure");
        return Results.Unauthorized();
    }

    var claims = new List<Claim>
    {
        new Claim("sub", user.UserName!),
        new Claim("uid", user.Id),
        new Claim("userId", user.Id)  // PHASE 1: Always Identity GUID for audit tracking
    };
    
    // Add role claims
    var roles = await um.GetRolesAsync(user);
    foreach (var role in roles)
    {
        claims.Add(new Claim("role", role));
    }
    
    // Add user claims (email, custom uid, etc.)
    var userClaims = await um.GetClaimsAsync(user);
    
    // Add email claim if exists
    var emailClaim = userClaims.FirstOrDefault(c => c.Type == "email");
    if (emailClaim != null)
    {
        claims.Add(emailClaim);
    }
    else if (!string.IsNullOrEmpty(user.Email))
    {
        // Fallback to user.Email if no email claim
        claims.Add(new Claim("email", user.Email));
    }
    
    // Add custom uid claim if exists (overrides default uid, userId remains Identity GUID)
    var customUid = userClaims.FirstOrDefault(c => c.Type == "uid");
    if (customUid != null)
    {
        claims.RemoveAll(c => c.Type == "uid");
        claims.Add(customUid);
        // Note: userId claim is NOT overridden - it always contains Identity GUID
    }

    await auditService.LogEventAsync(httpContext, user.UserName, "login", "success");

    var token = new System.IdentityModel.Tokens.Jwt.JwtSecurityToken(
        claims: claims,
        expires: DateTime.UtcNow.AddHours(1),
        signingCredentials: creds);

    var jwt = new System.IdentityModel.Tokens.Jwt.JwtSecurityTokenHandler().WriteToken(token);
    var refresh = store.Issue(user.UserName!);

    return Results.Ok(new
    {
        accessToken = jwt,
        refreshToken = refresh,
        access_token = jwt,
        refresh_token = refresh,
        token = jwt
    });
}).AllowAnonymous();

// /dev/* endpoints: Development only — not mapped in Alpha/Beta/Prod
if (app.Environment.IsDevelopment())
{
    app.MapPost("/dev/seed-drivers",
        async (UserManager<IdentityUser> um, RoleManager<IdentityRole> rm) =>
    {
        // Ensure driver role exists
        if (!await rm.RoleExistsAsync("driver"))
        {
            await rm.CreateAsync(new IdentityRole("driver"));
        }

        var created = new List<object>();

        // Define test drivers with predetermined GUIDs for consistency with AdminAPI seed data
        var testDrivers = new[]
        {
            new { Username = "charlie", Password = "password", UserUid = "driver-001" },
            new { Username = "driver_frank", Password = "password", UserUid = Guid.NewGuid().ToString("N") },
            new { Username = "driver_grace", Password = "password", UserUid = Guid.NewGuid().ToString("N") },
        };

        foreach (var d in testDrivers)
        {
            var existing = await um.FindByNameAsync(d.Username);
            if (existing is null)
            {
                var user = new IdentityUser { UserName = d.Username };
                var result = await um.CreateAsync(user, d.Password);
                if (result.Succeeded)
                {
                    await um.AddToRoleAsync(user, "driver");
                    await um.AddClaimAsync(user, new Claim("uid", d.UserUid));
                    created.Add(new { d.Username, d.UserUid });
                }
            }
            else
            {
                var claims = await um.GetClaimsAsync(existing);
                if (!claims.Any(c => c.Type == "uid"))
                {
                    await um.AddClaimAsync(existing, new Claim("uid", d.UserUid));
                    created.Add(new { d.Username, d.UserUid, updated = true });
                }
            }
        }

        return Results.Ok(new { message = "Driver users seeded.", created });
    }).AllowAnonymous();

    app.MapGet("/dev/user-info/{username}",
        async (string username,
               UserManager<IdentityUser> um,
               AuthAuditService auditService,
               HttpContext httpContext) =>
        {
        var user = await um.FindByNameAsync(username);
        if (user is null)
        {
            await auditService.LogEventAsync(httpContext, username, "role_assignment", "failure");
            return Results.NotFound(new { error = $"User '{username}' not found." });
        }

        var roles = await um.GetRolesAsync(user);
        var claims = await um.GetClaimsAsync(user);

        var hasDriverRole = roles.Contains("driver");
        var uidClaim = claims.FirstOrDefault(c => c.Type == "uid");
        var emailClaim = claims.FirstOrDefault(c => c.Type == "email");

        var jwtClaimsPreview = new List<object>
        {
            new { Type = "sub", Value = user.UserName },
            new { Type = "uid", Value = uidClaim?.Value ?? user.Id },
            new { Type = "userId", Value = user.Id }
        };

        foreach (var role in roles)
            jwtClaimsPreview.Add(new { Type = "role", Value = role });

        if (emailClaim != null || !string.IsNullOrEmpty(user.Email))
            jwtClaimsPreview.Add(new { Type = "email", Value = emailClaim?.Value ?? user.Email });

        return Results.Ok(new
        {
            userId = user.Id,
            username = user.UserName,
            email = user.Email,
            roles = roles,
            userClaims = claims.Select(c => new { c.Type, c.Value }).ToList(),
            jwtClaimsPreview,
            diagnostics = new
            {
                hasDriverRole,
                hasCustomUid = uidClaim != null,
                customUidValue = uidClaim?.Value,
                identityGuid = user.Id,
                hasEmail = emailClaim != null || !string.IsNullOrEmpty(user.Email),
                phase1Ready = true,
                notes = new
                {
                    uidClaim = uidClaim != null
                        ? "Custom UID will override default in JWT (driver pattern)"
                        : "JWT will use Identity GUID for uid claim",
                    userIdClaim = "Phase 1: userId claim always contains Identity GUID for audit tracking",
                    auditRecommendation = "AdminAPI should use 'userId' claim for CreatedByUserId field"
                }
            }
        });
    }).AllowAnonymous();
}

// PHASE 2: Role assignment endpoint (admin-only) - DEPRECATED
// This endpoint is maintained for backward compatibility only
// Use PUT /api/admin/users/{userId}/roles instead (controller-based)
app.MapPut("/api/admin/users/{username}/role",
    async (
        string username,
        RoleAssignmentRequest? request,
        UserManager<IdentityUser> um,
        RoleManager<IdentityRole> rm,
        AuthAuditService auditService,
        HttpContext httpContext) =>
{
    if (request is null || string.IsNullOrWhiteSpace(request.Role))
    {
        return Results.BadRequest(new { error = "Role is required in request body." });
    }

    // Validate role exists
    var validRoles = new[] { "admin", "dispatcher", "booker", "driver" };
    var requestedRole = request.Role.ToLowerInvariant();
    
    if (!validRoles.Contains(requestedRole))
    {
        return Results.BadRequest(new 
        { 
            error = $"Invalid role '{request.Role}'. Valid roles are: {string.Join(", ", validRoles)}" 
        });
    }

    // Find user
    var user = await um.FindByNameAsync(username);
    if (user is null)
    {
        await auditService.LogEventAsync(httpContext, username, "role_assignment", "failure");
        return Results.NotFound(new { error = $"User '{username}' not found." });
    }

    // Get current roles
    var currentRoles = await um.GetRolesAsync(user);
    
    // Check if user already has ONLY this role (optimization - skip if already correct)
    if (currentRoles.Count == 1 && currentRoles.Contains(requestedRole))
    {
        return Results.Ok(new 
        { 
            message = $"User '{username}' already has role '{requestedRole}' (no change needed).",
            username = user.UserName,
            role = requestedRole,
            previousRoles = currentRoles,
            newRole = requestedRole,
            deprecated = "Use PUT /api/admin/users/{userId}/roles instead"
        });
    }

    // Remove all existing roles (mutually exclusive strategy)
    if (currentRoles.Any())
    {
        var removeResult = await um.RemoveFromRolesAsync(user, currentRoles);
        if (!removeResult.Succeeded)
        {
            return Results.Problem(
                detail: string.Join(", ", removeResult.Errors.Select(e => e.Description)),
                title: "Failed to remove existing roles");
        }
    }

    // Add new role
    var addResult = await um.AddToRoleAsync(user, requestedRole);
    if (!addResult.Succeeded)
    {
        await auditService.LogEventAsync(httpContext, user.UserName, "role_assignment", "failure");
        return Results.Problem(
            detail: string.Join(", ", addResult.Errors.Select(e => e.Description)),
            title: "Failed to assign new role");
    }

    await auditService.LogEventAsync(httpContext, user.UserName, "role_assignment", "success");

    return Results.Ok(new
    {
        message = $"Successfully assigned role '{requestedRole}' to user '{username}'.",
        username = user.UserName,
        previousRoles = currentRoles,
        newRole = requestedRole,
        deprecated = "Use PUT /api/admin/users/{userId}/roles instead"
    });
})
.RequireAuthorization("AdminOnly");

// Health endpoints (anonymous)
app.MapGet("/health/live", (HttpContext context) =>
{
    return Results.Ok(new { status = "live", correlationId = context.Items[CorrelationIdMiddleware.CorrelationItemKey]?.ToString() });
}).AllowAnonymous();

app.MapGet("/health/ready", async (ApplicationDbContext db, SigningKeyState signingKeyState, HttpContext context) =>
{
    var dbReady = await db.Database.CanConnectAsync();
    var keyReady = signingKeyState.IsLoaded;

    if (!dbReady || !keyReady)
    {
        return Results.Problem(statusCode: 503, title: "Service not ready", detail: "Database connectivity or signing key readiness failed.");
    }

    return Results.Ok(new
    {
        status = "ready",
        database = "connected",
        signingKey = "loaded",
        correlationId = context.Items[CorrelationIdMiddleware.CorrelationItemKey]?.ToString()
    });
}).AllowAnonymous();

// Backward-compatible aliases � kept for Alpha test scripts and docs
// TODO(beta-cleanup): remove once all scripts/docs reference /health/live and /health/ready
app.MapGet("/health", (HttpContext context) =>
{
    return Results.Ok(new { status = "live", correlationId = context.Items[CorrelationIdMiddleware.CorrelationItemKey]?.ToString() });
}).AllowAnonymous();

app.MapGet("/healthz", async (ApplicationDbContext db, SigningKeyState signingKeyState, HttpContext context) =>
{
    var dbReady = await db.Database.CanConnectAsync();
    var keyReady = signingKeyState.IsLoaded;

    if (!dbReady || !keyReady)
    {
        return Results.Problem(statusCode: 503, title: "Service not ready", detail: "Database connectivity or signing key readiness failed.");
    }

    return Results.Ok(new
    {
        status = "ready",
        database = "connected",
        signingKey = "loaded",
        correlationId = context.Items[CorrelationIdMiddleware.CorrelationItemKey]?.ToString()
    });
}).AllowAnonymous();

app.Run();

// DTOs
public record LoginRequest(string Username, string Password);

// PHASE 2: Role assignment request
public record RoleAssignmentRequest(string Role);
