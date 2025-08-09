using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using BellwoodAuthServer.Data;

var builder = WebApplication.CreateBuilder(args);

// 1) EF Core + Identity (SQLite)
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
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddSignInManager();

// 2) JWT signing key + validation (same key the Rides API uses)
var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes("super-long-jwt-signing-secret-1234"));
var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

builder.Services
  .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
  .AddJwtBearer(o =>
  {
      o.TokenValidationParameters = new TokenValidationParameters
      {
          ValidateIssuer = false,
          ValidateAudience = false,
          ValidateLifetime = true,
          IssuerSigningKey = key
      };
  });

builder.Services.AddAuthorization();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// 3) Auto-migrate + seed test users on startup
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    await db.Database.MigrateAsync();

    var um = scope.ServiceProvider.GetRequiredService<UserManager<IdentityUser>>();

    async Task EnsureUser(string user, string pw)
    {
        if (await um.FindByNameAsync(user) is null)
        {
            var u = new IdentityUser { UserName = user };
            await um.CreateAsync(u, pw);
        }
    }

    await EnsureUser("alice", "password");
    await EnsureUser("bob", "password");
}

// 4) Pipeline
app.UseSwagger();
app.UseSwaggerUI();
app.UseAuthentication();
app.UseAuthorization();

// 5) Minimal login endpoint (POST /login {username,password} -> {token})
app.MapPost("/login", async (UserManager<IdentityUser> um, LoginRequest req) =>
{
    var user = await um.FindByNameAsync(req.Username);
    if (user is null || !(await um.CheckPasswordAsync(user, req.Password)))
        return Results.Unauthorized();

    var token = new System.IdentityModel.Tokens.Jwt.JwtSecurityToken(
        claims: new[] {
            new Claim("sub", user.UserName!),
            new Claim("uid", user.Id)
        },
        expires: DateTime.UtcNow.AddHours(1),
        signingCredentials: creds);

    var jwt = new System.IdentityModel.Tokens.Jwt.JwtSecurityTokenHandler().WriteToken(token);
    return Results.Ok(new { token = jwt });
});

app.Run();

// DTO
public record LoginRequest(string Username, string Password);
