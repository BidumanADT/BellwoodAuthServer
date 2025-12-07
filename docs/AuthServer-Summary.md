# BellwoodAuthServer - Function & Token Generation Summary

## Overview

The BellwoodAuthServer is an ASP.NET Core 8 authentication server that provides JWT token-based authentication for the Bellwood ride-sharing system. It uses ASP.NET Core Identity with Entity Framework Core (SQLite) for user management and supports multiple authentication endpoints for different client applications.

---

## Architecture

### Core Components

| Component | Purpose |
|-----------|---------|
| `ApplicationDbContext` | EF Core DbContext extending `IdentityDbContext` for user/role storage |
| `RefreshTokenStore` | In-memory concurrent dictionary for refresh token management |
| `UserManager<IdentityUser>` | ASP.NET Core Identity service for user operations |
| `RoleManager<IdentityRole>` | ASP.NET Core Identity service for role management |

### Database

- **Engine**: SQLite
- **Connection**: `Data Source=./bellwood-auth.db`
- **Tables**: Standard ASP.NET Core Identity tables (AspNetUsers, AspNetRoles, AspNetUserClaims, AspNetUserRoles, etc.)

---

## Authentication Endpoints

### 1. JSON Login (`POST /login` and `POST /api/auth/login`)

**Purpose**: Simple JSON-based authentication for mobile/web applications.

**Request Body**:
```json
{
  "username": "charlie",
  "password": "password"
}
```

**Response**:
```json
{
  "accessToken": "<jwt>",
  "refreshToken": "<guid>",
  "access_token": "<jwt>",
  "refresh_token": "<guid>",
  "token": "<jwt>"
}
```

**Token Claims Generated**:
- `sub`: Username
- `uid`: Custom uid claim (if set) OR user's internal Identity ID
- `role`: User's role(s) (e.g., "driver")

### 2. OAuth2-Style Token (`POST /connect/token`)

**Purpose**: OAuth2-compatible endpoint supporting `password` and `refresh_token` grant types.

**Supported Grant Types**:

#### Password Grant
```
grant_type=password
client_id=bellwood-maui-dev (optional)
username=charlie
password=password
scope=api.rides offline_access
```

#### Refresh Token Grant
```
grant_type=refresh_token
refresh_token=<refresh_token>
```

**Response**:
```json
{
  "access_token": "<jwt>",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "api.rides offline_access",
  "refresh_token": "<guid>"
}
```

**Token Claims Generated**:
- `sub`: Username
- `uid`: Custom uid claim (if set) OR user's internal Identity ID
- `role`: User's role(s)
- `scope`: Requested or default scope

---

## JWT Token Structure

### Token Configuration

| Property | Value |
|----------|-------|
| Algorithm | HS256 (HMAC-SHA256) |
| Signing Key | `super-long-jwt-signing-secret-1234` |
| Expiration | 1 hour from issue time |
| Clock Skew | Zero (strict expiration) |

### Standard Claims

| Claim | Source | Description |
|-------|--------|-------------|
| `sub` | `user.UserName` | Subject - the username |
| `uid` | Custom claim OR `user.Id` | User identifier for linking to Driver records |
| `role` | User roles | One claim per role (e.g., "driver") |
| `scope` | Request or default | Access scope(s) granted |

### Custom UID Claim Handling

The system supports custom `uid` claims that override the default user ID:

1. Default: `uid` = `user.Id` (ASP.NET Identity GUID)
2. Override: If user has a custom `uid` claim in AspNetUserClaims, that value is used instead

**This is critical for the driver assignment flow**:
- Driver records in AdminAPI have a `UserUid` field
- When a driver logs in, their JWT contains the matching `uid` claim
- The DriverApp API filters bookings by `AssignedDriverUid == jwt.uid`

---

## Token Generation Flow

```
???????????????????       POST /login           ???????????????????
?   Client App    ? ??????????????????????????? ?   AuthServer    ?
?                 ?   { username, password }    ?                 ?
?                 ?                             ? 1. Validate     ?
?                 ?                             ?    credentials  ?
?                 ?                             ? 2. Get roles    ?
?                 ?                             ? 3. Get custom   ?
?                 ?                             ?    uid claim    ?
?                 ?                             ? 4. Build JWT    ?
?                 ?                             ? 5. Issue refresh?
?                 ???????????????????????????????                 ?
?                 ?   { accessToken, refresh }  ?                 ?
???????????????????                             ???????????????????
```

### Code Path (Minimal API /login endpoint)

```csharp
// 1. Validate user
var user = await um.FindByNameAsync(req.Username);
if (user is null || !(await um.CheckPasswordAsync(user, req.Password)))
    return Results.Unauthorized();

// 2. Build claims list
var claims = new List<Claim>
{
    new Claim("sub", user.UserName!),
    new Claim("uid", user.Id)  // Default uid
};

// 3. Add role claims
var roles = await um.GetRolesAsync(user);
foreach (var role in roles)
    claims.Add(new Claim("role", role));

// 4. Override uid if custom claim exists
var userClaims = await um.GetClaimsAsync(user);
var customUid = userClaims.FirstOrDefault(c => c.Type == "uid");
if (customUid != null)
{
    claims.RemoveAll(c => c.Type == "uid");
    claims.Add(customUid);
}

// 5. Generate JWT
var token = new JwtSecurityToken(
    claims: claims,
    expires: DateTime.UtcNow.AddHours(1),
    signingCredentials: creds);

var jwt = new JwtSecurityTokenHandler().WriteToken(token);
var refresh = store.Issue(user.UserName!);
```

---

## User Management

### Admin Endpoints (`/api/admin/users`)

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/admin/users/drivers` | POST | Create new driver user with uid |
| `/api/admin/users/drivers` | GET | List all driver users |
| `/api/admin/users/{username}/uid` | PUT | Update user's uid claim |
| `/api/admin/users/by-uid/{userUid}` | GET | Find user by uid claim |
| `/api/admin/users/drivers/{username}` | DELETE | Delete driver user |

### Create Driver User Request
```json
{
  "username": "new_driver",
  "password": "securepassword",
  "userUid": "a1b2c3d4e5f6..."
}
```

The `userUid` should match the `UserUid` field set on the Driver record in AdminAPI.

### Dev Seed Endpoint (`POST /dev/seed-drivers`)

Seeds test driver users for development/testing. Creates users with the "driver" role and corresponding uid claims.

---

## Test Users (Seeded on Startup)

| Username | Password | Role | UID Claim |
|----------|----------|------|-----------|
| alice | password | (none) | (none - uses Identity ID) |
| bob | password | (none) | (none - uses Identity ID) |
| charlie | password | driver | `driver-001` |
| driver_dave | password | driver | (GUID) |
| driver_eve | password | driver | (GUID) |

---

## Refresh Token Management

### RefreshTokenStore Service

```csharp
public class RefreshTokenStore
{
    private readonly ConcurrentDictionary<string, string> _rtToUser = new();

    // Issue a new refresh token for a username
    public string Issue(string username)
    {
        var token = Guid.NewGuid().ToString("N");
        _rtToUser[token] = username;
        return token;
    }

    // Redeem (one-time use) a refresh token
    public bool TryRedeem(string refreshToken, out string username)
    {
        if (_rtToUser.TryRemove(refreshToken, out username))
            return true;
        username = "";
        return false;
    }
}
```

**Characteristics**:
- In-memory storage (tokens lost on restart)
- One-time use (token removed after redemption)
- Token rotation on refresh (new refresh token issued)

---

## Scalability Considerations

### Current Implementation

1. **GUID-based UIDs**: New driver users are created with GUID-based `userUid` values instead of sequential codes like "driver-001"

2. **Admin API Integration**: The `userUid` value in AuthServer should match the `UserUid` field on Driver records in AdminAPI

3. **Uniqueness Validation**: The admin endpoints validate that uid claims are unique across users

### Future Enhancements

1. **Persistent Refresh Tokens**: Replace in-memory `RefreshTokenStore` with database storage for high availability

2. **Token Revocation**: Add endpoint to revoke refresh tokens (e.g., on logout)

3. **Admin Authorization**: Protect `/api/admin/users/*` endpoints with admin role authentication

4. **External Identity Provider**: Consider OAuth2/OpenID Connect integration for enterprise scenarios

---

## Integration with Other Services

### AdminAPI Integration

```
???????????????????                              ???????????????????
?   AdminPortal   ?                              ?    AdminAPI     ?
?                 ?  POST /affiliates/{id}/      ?                 ?
? Create Driver   ???????????drivers?????????????? Store Driver    ?
? (userUid: xxx)  ?  { name, phone, userUid }    ? { UserUid: xxx }?
???????????????????                              ???????????????????
         ?
         ? Also call AuthServer
         ?
???????????????????
?   AuthServer    ?
?                 ?
? POST /api/admin/?
? users/drivers   ?
? { username,     ?
?   password,     ?
?   userUid: xxx }?
???????????????????
```

### DriverApp Flow

```
???????????????????       POST /login            ???????????????????
?    DriverApp    ? ??????????????????????????????   AuthServer    ?
?                 ?   { charlie, password }      ?                 ?
?                 ??????????????????????????????? JWT with        ?
?                 ?   { accessToken (uid=       ? uid="driver-001"?
?                 ?     "driver-001") }         ?                 ?
???????????????????                              ???????????????????
         ?
         ? GET /driver/rides/today
         ? Authorization: Bearer <jwt>
         ?
???????????????????
?    AdminAPI     ?
?                 ?
? Extract uid from?
? JWT claims      ?
?                 ?
? Filter bookings ?
? WHERE Assigned- ?
? DriverUid ==    ?
? "driver-001"    ?
???????????????????
```

---

## Configuration

### appsettings.json

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Data Source=./bellwood-auth.db"
  },
  "Jwt": {
    "Key": "super-long-jwt-signing-secret-1234"
  }
}
```

### Port Configuration

- HTTPS: `https://localhost:5001`
- HTTP: `http://localhost:5000`

---

## API Reference

### Public Endpoints (AllowAnonymous)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/login` | JSON login |
| POST | `/api/auth/login` | JSON login (alternate path) |
| POST | `/connect/token` | OAuth2-style token endpoint |
| GET | `/health` | Health check |
| GET | `/healthz` | Health check (k8s style) |
| POST | `/dev/seed-drivers` | Seed test drivers |

### Protected Endpoints (Require JWT)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/auth/me` | Get current user info and claims |

### Admin Endpoints (Currently AllowAnonymous - TODO: Protect)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/admin/users/drivers` | Create driver user |
| GET | `/api/admin/users/drivers` | List driver users |
| PUT | `/api/admin/users/{username}/uid` | Update user's uid |
| GET | `/api/admin/users/by-uid/{userUid}` | Find user by uid |
| DELETE | `/api/admin/users/drivers/{username}` | Delete driver user |
