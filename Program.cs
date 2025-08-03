using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using BellwoodAuthServer.Models;

var builder = WebApplication.CreateBuilder(args);

// 1) A very simple in-memory “user store”
var users = new Dictionary<string, string> { ["alice"] = "password", ["bob"] = "password" };

// 2) JWT settings
var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes("super-long-jwt-signing-secret-1234"));
var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

// 3) Add Authentication
builder.Services
  .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
  .AddJwtBearer(options =>
  {
      options.TokenValidationParameters = new TokenValidationParameters
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
app.UseSwagger();
app.UseSwaggerUI();

app.UseAuthentication();
app.UseAuthorization();

// 4) Login endpoint: accepts JSON { username, password }, returns { token }
app.MapPost("/login", (LoginRequest req) =>
{
    if (!users.TryGetValue(req.Username, out var pw) || pw != req.Password)
        return Results.Unauthorized();

    var token = new System.IdentityModel.Tokens.Jwt.JwtSecurityToken(
        claims: new[] { new System.Security.Claims.Claim("sub", req.Username) },
        expires: DateTime.UtcNow.AddHours(1),
        signingCredentials: creds);

    var tokenString = new System.IdentityModel.Tokens.Jwt.JwtSecurityTokenHandler()
        .WriteToken(token);

    return Results.Ok(new { token = tokenString });
});

app.Run();
