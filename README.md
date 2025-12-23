# Bellwood AuthServer

![.NET](https://img.shields.io/badge/.NET-8.0-512BD4?style=flat-square&logo=.net)
![Architecture](https://img.shields.io/badge/architecture-ASP.NET%20Identity%20%2B%20JWT-blue?style=flat-square)
![Status](https://img.shields.io/badge/status-Production%20Ready-success?style=flat-square)
![License](https://img.shields.io/badge/license-Proprietary-red?style=flat-square)

A production-ready authentication server for the Bellwood Global chauffeur and limousine management system, providing JWT-based authentication with role-based authorization and custom claims for multi-application integration.

## Overview

Bellwood AuthServer is the central identity provider powering the Bellwood ecosystem, enabling:

- ?? **JWT Authentication** – Secure token-based authentication for all Bellwood applications
- ?? **Role-Based Authorization** – Support for `admin`, `driver`, and `booker` roles with custom claims
- ?? **Custom Claims Management** – User-specific claims (uid, email) for cross-service integration
- ?? **Refresh Token Support** – Long-lived sessions with token rotation
- ?? **Multi-Application Support** – Single identity source for AdminPortal, PassengerApp, and DriverApp
- ??? **Admin Management** – RESTful endpoints for user and claim management
- ?? **Test User Seeding** – Auto-provisioned test accounts for rapid development

## Architecture

The Bellwood ecosystem consists of five interconnected components:

```
???????????????????    JWT Auth      ????????????????
?   AuthServer    ? ???????????????? ?  AdminAPI    ?
?  (This Repo)    ?                  ?              ?
???????????????????                  ????????????????
         ?                                   ?
         ?                                   ?
         ?????????????????????????????????????????????????????????????
         ?                                   ?                       ?
  ???????????????                    ???????????????        ???????????????
  ? AdminPortal ?                    ? PassengerApp?        ?  DriverApp  ?
  ?  (Blazor)   ?                    ?   (MAUI)    ?        ?   (MAUI)    ?
  ???????????????                    ???????????????        ???????????????
```

### Integration Points

| Component | Technology | Purpose | Required Claims |
|-----------|-----------|---------|----------------|
| **AdminPortal** | Blazor Server | Staff interface for dispatch and management | `role: admin` or `role: dispatcher` |
| **PassengerApp** | .NET MAUI | Customer booking and ride tracking | `email: {user@example.com}` |
| **DriverApp** | .NET MAUI | Driver assignments and GPS updates | `role: driver`, `uid: {driver-uid}` |
| **AdminAPI** | Minimal APIs | Backend services for all apps | Any valid JWT |

## Current Capabilities

### Core Features

- **JWT Token Issuance:** Standard JWT Bearer tokens with HS256 signing; configurable expiration (default: 1 hour); includes username (`sub`), user ID (`uid`), email, and role claims.
- **ASP.NET Core Identity:** Full Identity framework integration; SQLite database storage (`bellwood-auth.db`); support for roles, claims, and user management.
- **Role-Based Authorization:** Pre-configured roles: `admin`, `driver`, `booker`; automatic role claim injection into JWT tokens; extensible for additional roles.
- **Custom Claims:** `uid` claim links drivers to AdminAPI Driver records; `email` claim enables passenger authorization in AdminAPI; claims are persistent and user-specific.
- **Refresh Token Support:** In-memory refresh token storage; one-time use tokens with automatic rotation; `RefreshTokenStore` service for token management.
- **Test User Auto-Seeding:** Automatic creation of test users on startup; includes alice/bob (admins), chris (booker), charlie (driver); idempotent seeding logic (safe to restart).

### User Management Features

- **Admin Endpoints:** Create driver users with custom uid claims; update user uid claims; list all driver users; delete driver users; find users by uid.
- **Diagnostic Endpoints:** `/dev/user-info/{username}` shows roles, claims, and diagnostics; helps troubleshoot authorization issues; shows warnings for missing roles/claims.
- **Health Endpoints:** `/health` and `/healthz` for monitoring; anonymous access for load balancers and orchestrators.

## Project Structure

```
BellwoodAuthServer/
?? Controllers/                    # MVC API Controllers
?   ?? AdminUsersController.cs    # Admin user management endpoints
?   ?? AuthInfoController.cs      # User info and diagnostics
?   ?? AuthorizationController.cs # OAuth2-style token endpoint
?   ?? TokenController.cs         # Token refresh endpoint
?? Data/                           # EF Core DbContext
?   ?? ApplicationDbContext.cs    # Identity database context
?   ?? AuthDbContext.cs           # (Legacy - not used)
?? Migrations/                     # EF Core Migrations
?   ?? 20250809185925_InitialIdentity.cs
?? Services/                       # Business Services
?   ?? RefreshTokenStore.cs       # In-memory refresh token storage
?? Models/                         # DTOs
?   ?? LoginRequest.cs            # Login request model
?? Docs/                           # Comprehensive Documentation
?   ?? AuthServer-Summary.md      # Complete feature overview
?   ?? SOLUTION-SUMMARY.md        # Integration guide
?   ?? Charlie-403-Fix.md         # Driver authorization troubleshooting
?   ?? Testing-Charlie.md         # Driver testing guide
?   ?? [...].md                   # Additional guides
?? Program.cs                      # Application startup + Minimal APIs
?? appsettings.json               # Configuration
?? BellwoodAuthServer.csproj      # .NET 8 project file
?? bellwood-auth.db               # SQLite database (auto-created)
```

## Documentation

### Core Documentation

- `Docs/AuthServer-Summary.md` – Complete feature matrix and API reference
- `Docs/SOLUTION-SUMMARY.md` – System architecture and integration guide

### Troubleshooting Guides

- `Docs/Charlie-403-Fix.md` – Driver authorization troubleshooting
- `Docs/Testing-Charlie.md` – Step-by-step driver testing
- `Docs/AdminAPI-403-Fix.md` – AdminAPI integration fixes
- `Docs/Troubleshooting-403.md` – General 403 error diagnosis

**Total**: 7+ comprehensive documents (~15,000 words)

## Prerequisites

- [.NET 8.0 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- SQLite (bundled with .NET)

## Getting Started

### 1. Clone & Restore

```sh
git clone https://github.com/BidumanADT/QuickstartAuthServer.git
cd BellwoodAuthServer
dotnet restore
```

### 2. Configure

Update `appsettings.json` with your settings:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Data Source=./bellwood-auth.db"
  },
  "Serilog": {
    "MinimumLevel": {
      "Default": "Debug"
    }
  }
}
```

**?? IMPORTANT**: The JWT signing key is hardcoded in `Program.cs`:

```csharp
var key = new SymmetricSecurityKey(
    Encoding.UTF8.GetBytes("super-long-jwt-signing-secret-1234"));
```

**This key MUST match** the `Jwt:Key` setting in AdminAPI's `appsettings.json`. In production, move this to configuration and use a strong, unique secret.

### 3. Run

```sh
dotnet run
```

The server will start at:
- **HTTPS**: `https://localhost:5001`
- **HTTP**: `http://localhost:5000`
- **Swagger**: `https://localhost:5001/swagger`

### 4. Verify Test Users

On first run, the following users are automatically created:

| Username | Password | Role | Email | UID Claim | Purpose |
|----------|----------|------|-------|-----------|---------|
| `alice` | `password` | `admin` | - | (auto) | Admin user |
| `bob` | `password` | `admin` | - | (auto) | Admin user |
| `chris` | `password` | `booker` | `chris.bailey@example.com` | (auto) | Passenger/booker |
| `charlie` | `password` | `driver` | - | `driver-001` | Primary test driver |
| `driver_dave` | `password` | `driver` | - | (GUID) | Additional driver |
| `driver_eve` | `password` | `driver` | - | (GUID) | Additional driver |

### 5. Test Authentication

```sh
# Get JWT token for driver
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username": "charlie", "password": "password"}'

# Response includes:
# - accessToken: JWT for API authorization
# - refreshToken: For token renewal
# - token: Alias for accessToken
```

**Decode the token at [jwt.io](https://jwt.io) to verify claims:**

```json
{
  "sub": "charlie",
  "uid": "driver-001",
  "role": "driver",
  "exp": 1234567890
}
```

## API Endpoints

### Authentication

All endpoints require HTTPS in production. Development mode allows HTTP on port 5000.

### Public Endpoints (AllowAnonymous)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/login` | POST | JSON login - primary endpoint |
| `/api/auth/login` | POST | JSON login - alternate path |
| `/connect/token` | POST | OAuth2-style token endpoint (form-urlencoded) |
| `/api/auth/refresh` | POST | Refresh token endpoint |
| `/health` | GET | Health check |
| `/healthz` | GET | Health check (Kubernetes style) |

### Protected Endpoints (Require JWT)

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/api/auth/me` | GET | ? | Get current user info and claims |

### Admin Endpoints (Currently AllowAnonymous - TODO: Protect)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/admin/users/drivers` | POST | Create driver user with uid claim |
| `/api/admin/users/drivers` | GET | List all driver users |
| `/api/admin/users/{username}/uid` | PUT | Update user's uid claim |
| `/api/admin/users/by-uid/{userUid}` | GET | Find user by uid claim |
| `/api/admin/users/drivers/{username}` | DELETE | Delete driver user |

### Diagnostic Endpoints (Development)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/dev/user-info/{username}` | GET | Show user roles, claims, and diagnostics |
| `/dev/seed-drivers` | POST | Manually seed additional test drivers |

## Authentication Flows

### Standard Login Flow

```
????????????                          ????????????
?  Client  ?                          ?AuthServer?
????????????                          ????????????
     ? POST /login                         ?
     ? {username, password}                ?
     ???????????????????????????????????????
     ?                                     ?
     ?                    ??????????????????
     ?                    ? Validate user  ?
     ?                    ? Load roles     ?
     ?                    ? Load claims    ?
     ?                    ? Generate JWT   ?
     ?                    ? Issue refresh  ?
     ?                    ??????????????????
     ?                                     ?
     ? {accessToken, refreshToken}         ?
     ???????????????????????????????????????
     ?                                     ?
```

### Using JWT with AdminAPI

```
????????????                          ????????????
?  Client  ?                          ? AdminAPI ?
????????????                          ????????????
     ? GET /driver/rides/today             ?
     ? Authorization: Bearer {jwt}         ?
     ???????????????????????????????????????
     ?                                     ?
     ?                    ??????????????????
     ?                    ? Validate JWT   ?
     ?                    ? Check signature?
     ?                    ? Extract claims ?
     ?                    ? Verify role    ?
     ?                    ??????????????????
     ?                                     ?
     ? [{rides}]                           ?
     ???????????????????????????????????????
     ?                                     ?
```

### Refresh Token Flow

```
????????????                          ????????????
?  Client  ?                          ?AuthServer?
????????????                          ????????????
     ? POST /api/auth/refresh              ?
     ? {refreshToken}                      ?
     ???????????????????????????????????????
     ?                                     ?
     ?                    ??????????????????
     ?                    ? Validate token ?
     ?                    ? Redeem (1-time)?
     ?                    ? Generate new   ?
     ?                    ? JWT + refresh  ?
     ?                    ??????????????????
     ?                                     ?
     ? {accessToken, refreshToken}         ?
     ???????????????????????????????????????
     ?                                     ?
```

## JWT Token Structure

### Claims Included in JWT

```json
{
  "sub": "charlie",              // Username (NameClaimType)
  "uid": "driver-001",           // Custom UID (links to AdminAPI Driver.UserUid)
  "role": "driver",              // Role (RoleClaimType) - can be multiple
  "email": "chris.bailey@example.com", // Email (for passenger authorization)
  "exp": 1234567890,             // Expiration timestamp (Unix)
  "iat": 1234567890              // Issued at timestamp (Unix)
}
```

### Claim Usage by Application

| Application | Required Claims | Purpose |
|-------------|----------------|---------|
| **AdminPortal** | `role: admin` or `role: dispatcher` | Access admin management functions |
| **DriverApp** | `role: driver`, `uid: {driver-uid}` | See assigned rides, update status, send GPS |
| **PassengerApp** | `email: {user@example.com}` | Track own rides via email verification |
| **AdminAPI (Driver)** | `role: driver`, `uid: {driver-uid}` | Driver endpoint authorization |
| **AdminAPI (Passenger)** | `email: {user@example.com}` | Passenger tracking authorization |

### The UserUid Link (Critical)

The `uid` claim creates a critical link between AuthServer and AdminAPI:

```
AuthServer                AdminAPI                 DriverApp
??????????                ????????                 ?????????
User: charlie      ?      Driver:           ?      JWT Token:
uid: "driver-001"         UserUid: "driver-001"    uid: "driver-001"
                               ?
                          Booking:
                          AssignedDriverUid: "driver-001"
```

**How It Works:**
1. Driver "Charlie" logs in via AuthServer
2. AuthServer issues JWT with `uid: "driver-001"`
3. DriverApp sends JWT to AdminAPI
4. AdminAPI extracts `uid` claim from JWT
5. AdminAPI filters bookings where `AssignedDriverUid == "driver-001"`
6. Charlie sees only his assigned rides

**?? CRITICAL**: The `uid` claim value MUST match the `Driver.UserUid` field in AdminAPI, or the driver will see no rides.

## Login Endpoint Examples

### Standard Login (Recommended)

**Request:**
```sh
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "charlie",
    "password": "password"
  }'
```

**Response:**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "abc123def456...",
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "abc123def456...",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Note**: Multiple field names (`accessToken`, `access_token`, `token`) for client compatibility.

### OAuth2-Style Login

**Request:**
```sh
curl -X POST https://localhost:5001/connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&username=charlie&password=password"
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "abc123def456..."
}
```

### Refresh Token

**Request:**
```sh
curl -X POST https://localhost:5001/api/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{
    "refreshToken": "abc123def456..."
  }'
```

**Response:**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "xyz789abc012...",
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "xyz789abc012...",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Note**: Old refresh token is invalidated (one-time use). Store the new `refreshToken` for future use.

## Admin User Management

### Create Driver User

**Purpose:** Create a new driver user with a custom `uid` claim that matches the `Driver.UserUid` in AdminAPI.

**Request:**
```sh
curl -X POST https://localhost:5001/api/admin/users/drivers \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_driver",
    "password": "SecureP@ss123",
    "userUid": "driver-12345"
  }'
```

**Response:**
```json
{
  "message": "Driver user created successfully.",
  "userId": "abc123...",
  "username": "john_driver",
  "userUid": "driver-12345",
  "role": "driver"
}
```

**Validation:**
- Username must be unique
- `userUid` must be unique across all users
- Password follows Identity password policy (configurable in `Program.cs`)
- Automatically adds `role: driver`

### Update User UID

**Request:**
```sh
curl -X PUT https://localhost:5001/api/admin/users/john_driver/uid \
  -H "Content-Type: application/json" \
  -d '{
    "userUid": "driver-99999"
  }'
```

**Response:**
```json
{
  "message": "UserUid updated successfully.",
  "username": "john_driver",
  "oldUid": "driver-12345",
  "newUid": "driver-99999"
}
```

### List All Drivers

**Request:**
```sh
curl https://localhost:5001/api/admin/users/drivers
```

**Response:**
```json
{
  "count": 3,
  "drivers": [
    {
      "userId": "abc123...",
      "username": "charlie",
      "userUid": "driver-001",
      "roles": ["driver"]
    },
    {
      "userId": "def456...",
      "username": "driver_dave",
      "userUid": "a1b2c3d4e5f6...",
      "roles": ["driver"]
    }
  ]
}
```

### Find User by UID

**Request:**
```sh
curl https://localhost:5001/api/admin/users/by-uid/driver-001
```

**Response:**
```json
{
  "userId": "abc123...",
  "username": "charlie",
  "userUid": "driver-001",
  "roles": ["driver"],
  "email": null
}
```

### Delete Driver User

**Request:**
```sh
curl -X DELETE https://localhost:5001/api/admin/users/drivers/john_driver
```

**Response:**
```json
{
  "message": "Driver user deleted successfully.",
  "username": "john_driver"
}
```

## Diagnostic Endpoints

### User Info (Development)

Check a user's roles, claims, and potential issues:

**Request:**
```sh
curl https://localhost:5001/dev/user-info/charlie
```

**Response:**
```json
{
  "userId": "abc123...",
  "username": "charlie",
  "email": null,
  "roles": ["driver"],
  "claims": [
    {
      "type": "uid",
      "value": "driver-001"
    }
  ],
  "diagnostics": {
    "hasDriverRole": true,
    "hasUidClaim": true,
    "uidValue": "driver-001",
    "canAccessDriverEndpoints": true,
    "warning": null
  }
}
```

**If there's a problem:**
```json
{
  "userId": "def456...",
  "username": "broken_driver",
  "email": null,
  "roles": [],
  "claims": [],
  "diagnostics": {
    "hasDriverRole": false,
    "hasUidClaim": false,
    "uidValue": null,
    "canAccessDriverEndpoints": false,
    "warning": "?? User missing 'driver' role - will get 403 on driver endpoints"
  }
}
```

### Seed Additional Drivers

**Request:**
```sh
curl -X POST https://localhost:5001/dev/seed-drivers
```

**Response:**
```json
{
  "message": "Driver users seeded.",
  "created": [
    {
      "username": "driver_frank",
      "userUid": "a1b2c3d4e5f6..."
    },
    {
      "username": "driver_grace",
      "userUid": "f6e5d4c3b2a1..."
    }
  ]
}
```

## User Seeding on Startup

### Automatic Test User Creation

The application automatically creates test users on startup. The seeding logic is **idempotent** - it's safe to restart the server without duplicating users.

### Seeding Logic

**Roles** (created first):
```csharp
// Three roles are ensured to exist:
- "admin"    ? AdminPortal users
- "booker"   ? PassengerApp users
- "driver"   ? DriverApp users
```

**Test Users** (created if they don't exist):

**1. Alice & Bob (Admins):**
```csharp
// Basic users created
await EnsureUser("alice", "password");
await EnsureUser("bob", "password");

// Admin role added (even if users already existed)
if (!aliceRoles.Contains("admin"))
    await um.AddToRoleAsync(alice, "admin");
```

**2. Chris (Passenger/Booker):**
```csharp
// User created with email
passengerUser = new IdentityUser 
{ 
    UserName = "chris",
    Email = "chris.bailey@example.com",
    EmailConfirmed = true
};

// Booker role added
await um.AddToRoleAsync(passengerUser, "booker");

// Email claim added (for passenger tracking authorization)
await um.AddClaimAsync(passengerUser, 
    new Claim("email", "chris.bailey@example.com"));
```

**3. Charlie (Primary Driver):**
```csharp
// User created
driverUser = new IdentityUser { UserName = "charlie" };
await um.CreateAsync(driverUser, "password");

// Driver role added
await um.AddToRoleAsync(driverUser, "driver");

// UID claim added (links to AdminAPI Driver.UserUid)
await um.AddClaimAsync(driverUser, 
    new Claim("uid", "driver-001"));
```

**4. Additional Drivers (driver_dave, driver_eve):**
```csharp
// Uses GUID-based UIDs for scalability
await EnsureDriverUser("driver_dave", "password", Guid.NewGuid().ToString("N"));
await EnsureDriverUser("driver_eve", "password", Guid.NewGuid().ToString("N"));
```

### Idempotent Seeding

The seed logic handles existing users gracefully:

```csharp
// Check if user exists
var user = await um.FindByNameAsync("charlie");
if (user is null)
{
    // CREATE user if missing
    user = new IdentityUser { UserName = "charlie" };
    await um.CreateAsync(user, "password");
}

// ALWAYS ensure role exists (even if user already existed)
var roles = await um.GetRolesAsync(user);
if (!roles.Contains("driver"))
{
    await um.AddToRoleAsync(user, "driver");
}

// ALWAYS ensure uid claim exists (even if user already existed)
var claims = await um.GetClaimsAsync(user);
var uidClaim = claims.FirstOrDefault(c => c.Type == "uid");
if (uidClaim == null)
{
    await um.AddClaimAsync(user, new Claim("uid", "driver-001"));
}
else if (uidClaim.Value != "driver-001")
{
    // Fix incorrect uid value
    await um.RemoveClaimAsync(user, uidClaim);
    await um.AddClaimAsync(user, new Claim("uid", "driver-001"));
}
```

**Why This Matters:**
- ? Safe to restart the server multiple times
- ? Automatically fixes missing roles on existing users
- ? Automatically fixes missing claims on existing users
- ? Corrects incorrect uid values
- ? No duplicate users created

## Security & Configuration

### Password Policy

Configured in `Program.cs` for development ease:

```csharp
builder.Services
    .AddIdentityCore<IdentityUser>(o =>
    {
        o.Password.RequireNonAlphanumeric = false;
        o.Password.RequireUppercase = false;
        o.Password.RequireLowercase = false;
        o.Password.RequireDigit = false;
        o.Password.RequiredLength = 6;
    })
```

**?? Production**: Strengthen password requirements:
```csharp
o.Password.RequireNonAlphanumeric = true;
o.Password.RequireUppercase = true;
o.Password.RequireLowercase = true;
o.Password.RequireDigit = true;
o.Password.RequiredLength = 12;
o.Password.RequiredUniqueChars = 4;
```

### JWT Configuration

**Signing Key** (hardcoded in `Program.cs`):
```csharp
var key = new SymmetricSecurityKey(
    Encoding.UTF8.GetBytes("super-long-jwt-signing-secret-1234"));
```

**Token Parameters:**
```csharp
o.TokenValidationParameters = new TokenValidationParameters
{
    ValidateIssuer = false,       // No issuer validation
    ValidateAudience = false,     // No audience validation
    ValidateLifetime = true,      // ? Check expiration
    IssuerSigningKey = key,       // ? Verify signature
    ClockSkew = TimeSpan.Zero     // No clock skew tolerance
};
```

**Token Expiration:**
```csharp
expires: DateTime.UtcNow.AddHours(1)  // 1 hour lifetime
```

**?? Production Considerations:**
- Move JWT key to `appsettings.Production.json`
- Enable issuer and audience validation
- Use environment variables for secrets
- Consider shorter token lifetimes (15-30 minutes)
- Implement token revocation for logout

### Refresh Token Security

**Current Implementation:**
- In-memory storage (`ConcurrentDictionary`)
- Tokens are GUIDs (128-bit random)
- One-time use (removed after redemption)
- Token rotation on refresh
- Lost on server restart

**?? Production**: Replace `RefreshTokenStore` with:
- Database-backed storage (persistent)
- Token expiration timestamps
- Revocation support
- Rate limiting on refresh attempts

## Data Storage

### SQLite Database

**Location:** `./bellwood-auth.db` (project root)

**Schema:** ASP.NET Core Identity default schema
- `AspNetUsers` – User accounts
- `AspNetRoles` – Roles (admin, driver, booker)
- `AspNetUserRoles` – User-role assignments
- `AspNetUserClaims` – Custom claims (uid, email)
- `AspNetRoleClaims` – Role-based claims (not used)
- `AspNetUserLogins` – External logins (not used)
- `AspNetUserTokens` – Identity tokens (not used)

**Migrations:** Managed via EF Core migrations in `Migrations/` folder

**?? Production**: Consider PostgreSQL or SQL Server for:
- Better concurrency
- Enhanced security
- Backup/restore capabilities
- High availability

### Refresh Token Storage

**Current:** In-memory `ConcurrentDictionary` in `RefreshTokenStore`

**Limitations:**
- Lost on server restart
- Not distributed (single-instance only)
- No expiration timestamps

**?? Production**: Implement database-backed storage or Redis.

## Testing

### Manual Testing (curl)

**1. Test Login:**
```sh
# Charlie (driver)
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username": "charlie", "password": "password"}' \
  | jq

# Expected: accessToken with "role": "driver", "uid": "driver-001"
```

**2. Verify JWT Claims:**
```sh
# Copy accessToken from response
# Visit https://jwt.io
# Paste token in "Encoded" section
# Verify payload has: sub, uid, role, exp
```

**3. Test User Info:**
```sh
curl https://localhost:5001/dev/user-info/charlie | jq

# Expected: hasDriverRole: true, hasUidClaim: true
```

**4. Test Admin API Integration:**
```sh
# Get token
TOKEN=$(curl -s -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username": "charlie", "password": "password"}' \
  | jq -r '.token')

# Call AdminAPI
curl https://localhost:5206/driver/rides/today \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Timezone-Id: America/Chicago"
```

### PowerShell Testing

Located in `Scripts/` (if available):

```powershell
# Test charlie login
.\test-charlie.ps1

# Test complete flow (AuthServer + AdminAPI)
.\test-adminapi.ps1
```

### Automated Testing Checklist

- [ ] Alice can login and receive admin role
- [ ] Bob can login and receive admin role
- [ ] Chris can login and receive booker role + email claim
- [ ] Charlie can login and receive driver role + uid claim
- [ ] JWT tokens expire after 1 hour
- [ ] Refresh tokens can be redeemed once
- [ ] Old refresh tokens fail after redemption
- [ ] `/dev/user-info/{username}` shows correct roles/claims
- [ ] AdminAPI accepts tokens and validates signature
- [ ] DriverApp can retrieve assigned rides with Charlie's token

## Troubleshooting

### Common Issues

**1. Charlie gets 403 Forbidden in AdminAPI**

**Symptoms:**
- Login succeeds, JWT received
- AdminAPI returns `403 Forbidden` on `/driver/rides/today`

**Diagnosis:**
```sh
curl https://localhost:5001/dev/user-info/charlie
```

**Fix:**
- If `hasDriverRole: false`: Restart AuthServer (will re-seed role)
- If `hasUidClaim: false`: Restart AuthServer (will re-seed claim)
- If `uidValue` wrong: Manually fix via `/api/admin/users/charlie/uid`

**Root Cause:** User created before seed logic was updated. Seed now handles existing users.

**2. JWT signature validation fails**

**Symptoms:**
```
SecurityTokenInvalidSignatureException: IDX10503: Signature validation failed
```

**Diagnosis:** JWT signing keys don't match between AuthServer and AdminAPI

**Fix:**
- Verify `Program.cs` in AuthServer:
  ```csharp
  var key = new SymmetricSecurityKey(
      Encoding.UTF8.GetBytes("super-long-jwt-signing-secret-1234"));
  ```
- Verify `appsettings.json` in AdminAPI:
  ```json
  {
    "Jwt": {
      "Key": "super-long-jwt-signing-secret-1234"
    }
  }
  ```
- Keys MUST match exactly

**3. Token expired**

**Symptoms:**
```
SecurityTokenExpiredException: IDX10223: Lifetime validation failed
```

**Fix:** Request a new token via `/login` or use refresh token via `/api/auth/refresh`

**4. Database locked errors**

**Symptoms:**
```
SQLite Error 5: 'database is locked'
```

**Diagnosis:** Multiple processes accessing SQLite database

**Fix:**
- Ensure only one instance of AuthServer is running
- In production, use PostgreSQL or SQL Server

**5. User not found after seeding**

**Symptoms:** `/dev/user-info/charlie` returns 404

**Diagnosis:** Seed logic didn't run or failed silently

**Fix:**
- Check console output for seed errors
- Delete `bellwood-auth.db` and restart (fresh seed)
- Manually create user via `/api/admin/users/drivers`

## Deployment

### Build

```sh
# Development
dotnet build

# Production
dotnet build -c Release
```

### Publish

```sh
# Self-contained (includes .NET runtime)
dotnet publish -c Release -r win-x64 --self-contained

# Framework-dependent (requires .NET 8 on server)
dotnet publish -c Release
```

### Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `ASPNETCORE_ENVIRONMENT` | Environment (Development/Production) | `Development` |
| `ASPNETCORE_URLS` | Listening URLs | `https://localhost:5001;http://localhost:5000` |
| `ConnectionStrings__DefaultConnection` | SQLite database path | `Data Source=./bellwood-auth.db` |

### Production Checklist

- [ ] Move JWT signing key to `appsettings.Production.json`
- [ ] Use strong, unique JWT secret (64+ characters)
- [ ] Strengthen password policy
- [ ] Replace SQLite with PostgreSQL or SQL Server
- [ ] Implement database-backed refresh token storage
- [ ] Protect admin endpoints with `[Authorize(Roles = "admin")]`
- [ ] Enable issuer and audience validation in JWT
- [ ] Set up HTTPS certificates
- [ ] Configure CORS for production domains
- [ ] Enable detailed logging for diagnostics
- [ ] Set up health check monitoring
- [ ] Implement token revocation on logout
- [ ] Add rate limiting on login endpoints
- [ ] Remove or protect `/dev/*` endpoints

## Monitoring & Logging

### Console Logging

Key events logged to console (via Serilog):

```
?? User charlie authenticated successfully
? JWT token issued for charlie (role: driver, uid: driver-001)
?? Refresh token redeemed for charlie
?? Failed login attempt for user: hacker123
? Token validation failed: SecurityTokenExpiredException
```

### Health Check

```sh
curl https://localhost:5001/health
```

Returns:
```json
{
  "status": "ok"
}
```

### Swagger UI

Available at `https://localhost:5001/swagger` for interactive API testing.

## Roadmap

### Short-Term (Q1 2025)

- [ ] Protect admin endpoints with `[Authorize(Roles = "admin")]`
- [ ] Implement token revocation on logout
- [ ] Add rate limiting on login endpoints
- [ ] Database-backed refresh token storage
- [ ] Enhanced logging for security events

### Long-Term (2025+)

- [ ] OAuth2/OpenID Connect integration for enterprise SSO
- [ ] Multi-factor authentication (MFA) support
- [ ] External identity providers (Google, Microsoft, etc.)
- [ ] Audit logging for admin actions
- [ ] Token introspection endpoint
- [ ] Passwordless authentication (magic links, WebAuthn)

## Branches

- **main** – Stable production code

## Support

For issues or questions:

- **GitHub Issues**: [https://github.com/BidumanADT/QuickstartAuthServer/issues](https://github.com/BidumanADT/QuickstartAuthServer/issues)
- **Documentation**: See `Docs/` directory (7+ comprehensive guides)

---

## Key Features Summary

? **JWT Authentication** with HS256 signing and 1-hour expiration  
? **Role-Based Authorization** (admin, driver, booker) with automatic claim injection  
? **Custom Claims** (uid, email) for cross-service integration  
? **Refresh Token Support** with one-time use and token rotation  
? **ASP.NET Core Identity** with SQLite database storage  
? **Auto-Seeding** of test users (alice, bob, chris, charlie, drivers)  
? **Admin Endpoints** for user and claim management  
? **Diagnostic Tools** (`/dev/user-info/{username}`) for troubleshooting  
? **Multi-Application Support** (AdminPortal, PassengerApp, DriverApp)  
? **Production-Ready** with comprehensive documentation and testing guides  

---

**Built with care using .NET 8 ASP.NET Core Identity + JWT**

*© 2025 Biduman ADT / Bellwood Global. All rights reserved.*
