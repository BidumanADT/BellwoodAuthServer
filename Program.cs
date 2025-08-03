using Microsoft.EntityFrameworkCore;
using OpenIddict.Abstractions;
using OpenIddict.Validation.AspNetCore;
using static OpenIddict.Abstractions.OpenIddictConstants;

static WebApplicationBuilder ConfigureServices(this WebApplicationBuilder builder)
{
    // 1. EF Core + OpenIddict stores
    builder.Services.AddDbContext<AuthDbContext>(options =>
    {
        options.UseSqlite("Data Source=auth.db");
        // register the OpenIddict entities/models
        options.UseOpenIddict();
    });

    // 2. OpenIddict
    builder.Services.AddOpenIddict()
        .AddCore(options =>
        {
            options.UseEntityFrameworkCore()
                   .UseDbContext<AuthDbContext>();
        })
        .AddServer(options =>
        {
            // Enable the authorization code flow + PKCE
            options.AllowAuthorizationCodeFlow()
                   .RequireProofKeyForCodeExchange();

            // Authorization endpoints
            options.SetAuthorizationEndpointUris("/connect/authorize")
                   .SetTokenEndpointUris("/connect/token")
                   .SetUserinfoEndpointUris("/connect/userinfo");

            // Issue JSON Web Tokens
            options.AddDevelopmentEncryptionCertificate()
                   .AddDevelopmentSigningCertificate();

            // ASP-NET integration
            options.UseAspNetCore()
                   .EnableAuthorizationEndpointPassthrough()
                   .EnableTokenEndpointPassthrough()
                   .DisableTransportSecurityRequirement(); // only for dev!
        })
        .AddValidation(options =>
        {
            // tell the validation handler to use our local server instance
            options.UseLocalServer();
            options.UseAspNetCore();
        });

    // 3. MVC Controllers (for the authorize/token endpoints)
    builder.Services.AddControllersWithViews();

    return builder;
}

static WebApplication ConfigurePipeline(this WebApplication app)
{
    app.UseSerilogRequestLogging();
    app.UseRouting();

    // OpenIddict’s endpoints are now handled as MVC controllers
    app.UseAuthentication();
    app.UseAuthorization();

    app.MapControllers();

    // Seed the database with a test client & scope
    using var scope = app.Services.CreateScope();
    var context = scope.ServiceProvider.GetRequiredService<AuthDbContext>();
    context.Database.Migrate();

    var apps = scope.ServiceProvider.GetRequiredService<IOpenIddictApplicationManager>();
    if (await apps.FindByClientIdAsync("bellwood.passenger") == null)
    {
        await apps.CreateAsync(new OpenIddictApplicationDescriptor
        {
            ClientId = "bellwood.passenger",
            RedirectUris = { new Uri("com.bellwoodglobal.mobile://callback") },
            Permissions =
            {
                Permissions.Endpoints.Authorization,
                Permissions.Endpoints.Token,
                Permissions.GrantTypes.AuthorizationCode,
                Permissions.ResponseTypes.Code,
                Permissions.Prefixes.Scope + "ride.api"
            }
        });
    }

    var scopes = scope.ServiceProvider.GetRequiredService<IOpenIddictScopeManager>();
    if (await scopes.FindByNameAsync("ride.api") == null)
    {
        await scopes.CreateAsync(new OpenIddictScopeDescriptor
        {
            Name = "ride.api",
            Resources = { "resource_server" }
        });
    }

    return app;
}
