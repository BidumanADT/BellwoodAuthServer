using Duende.IdentityServer;
using QuickstartAuthServer;
using Serilog;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;

namespace BellwoodAuthServer
{
    internal static class HostingExtensions
    {
        // 1) Change return type from WebApplicationBuilder -> WebApplication
        public static WebApplication ConfigureServices(this WebApplicationBuilder builder)
        {
            // 1) Register Razor Pages (Quickstart UI lives under /Pages)
            builder.Services.AddRazorPages();

            // 2) Configure Duende IdentityServer with your in-memory config
            builder.Services
                .AddIdentityServer(options =>
                {
                    options.Events.RaiseSuccessEvents = true;
                    options.Events.RaiseFailureEvents = true;
                    options.KeyManagement.Enabled = false;
                })
                .AddDeveloperSigningCredential()
                .AddInMemoryIdentityResources(Config.GetIdentityResources())
                .AddInMemoryApiScopes(Config.GetApiScopes())
                .AddInMemoryApiResources(Config.GetApiResources())
                .AddInMemoryClients(Config.GetClients())
                .AddTestUsers(Config.GetTestUsers());

            // 3) (Optional) External providers, e.g. Google
            builder.Services.AddAuthentication()
                .AddGoogle(options =>
                {
                    options.SignInScheme = IdentityServerConstants.ExternalCookieAuthenticationScheme;
                    options.ClientId = "GOOGLE_CLIENT_ID";
                    options.ClientSecret = "GOOGLE_CLIENT_SECRET";
                });

            // 2) Return builder.Build() so we get a WebApplication here
            return builder.Build();
        }

        public static WebApplication ConfigurePipeline(this WebApplication app)
        {
            app.UseSerilogRequestLogging();

            if (app.Environment.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }

            // 1) Static files + routing
            app.UseStaticFiles();
            app.UseRouting();

            // 2) Ensure the IdentityServer cookie is read
            app.UseAuthentication();

            // 3) IdentityServer + authorization
            app.UseIdentityServer();
            app.UseAuthorization();

            // 4) Map *only* Razor Pages (no global authorization filter)
            app.MapRazorPages();

            return app;
        }
    }
}
