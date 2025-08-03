using System.Collections.Generic;
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Test;

namespace BellwoodAuthServer;

public static class Config
{
    // 1) Identity resources
    public static IEnumerable<IdentityResource> GetIdentityResources() =>
        new IdentityResource[]
        {
            new IdentityResources.OpenId(),
            new IdentityResources.Profile()
        };

    // 2) API scopes
    public static IEnumerable<ApiScope> GetApiScopes() =>
        new ApiScope[]
        {
            new ApiScope("ride.api",   "Ride API"),
            new ApiScope("rating.api", "Rating API")
        };

    // 3) API resources
    public static IEnumerable<ApiResource> GetApiResources() =>
        new ApiResource[]
        {
            new ApiResource("ride.api",   "Ride API")   { Scopes = { "ride.api" } },
            new ApiResource("rating.api", "Rating API") { Scopes = { "rating.api" } }
        };

    // 4) Clients
    public static IEnumerable<Client> GetClients() =>
        new Client[]
        {
            new Client
            {
                ClientId            = "bellwood.passenger",
                AllowedGrantTypes   = GrantTypes.Code,
                RequirePkce         = true,
                RequireClientSecret = false,
                RedirectUris        = { "com.bellwoodglobal.mobile://callback" },
                PostLogoutRedirectUris = { "com.bellwoodglobal.mobile://signout-callback" },
                AllowedScopes       = { "openid", "profile", "ride.api", "rating.api" },
                AllowOfflineAccess  = true
            },
            new Client
            {
                ClientId          = "bellwood.admin",
                AllowedGrantTypes = GrantTypes.ClientCredentials,
                ClientSecrets     = { new Secret("admin_secret".Sha256()) },
                AllowedScopes     = { "ride.api", "rating.api" }
            }
        };

    // 5) Test users
    public static List<TestUser> GetTestUsers() => new List<TestUser>
    {
        new TestUser { SubjectId="1", Username="alice", Password="Pass123!" },
        new TestUser { SubjectId="2", Username="bob",   Password="Pass123!" }
    };
}

