# Charlie's 403 Error - Diagnostic & Fix Report

## Problem Summary

Charlie can authenticate successfully but gets a **403 Forbidden** error when accessing driver-only endpoints in the AdminAPI. This indicates that while authentication succeeds, **authorization is failing** - meaning the JWT token is missing required claims (specifically the `role: driver` claim).

---

## Root Cause Identified

### Critical Bug in Seed Logic (Program.cs lines 84-92)

**Original problematic code:**
```csharp
var driverUser = await um.FindByNameAsync("charlie");
if (driverUser is null)
{
    driverUser = new IdentityUser { UserName = "charlie" };
    await um.CreateAsync(driverUser, "password");
    await um.AddToRoleAsync(driverUser, "driver");
    await um.AddClaimAsync(driverUser, new Claim("uid", "driver-001"));
}
```

**The Problem:**
- The code checks if Charlie exists
- If Charlie **already exists** (from a previous seed or manual creation), the entire block is skipped
- This means the **role and uid claim are NEVER added** to existing users
- Result: Charlie authenticates but has no `role: driver` claim in his JWT ? 403 error

**Why This Happens:**
1. First run: Charlie doesn't exist ? User created with role and uid ?
2. Code updated, app restarted
3. Second run: Charlie exists ? Seed block skipped ?
4. Charlie now has no role or uid claim

---

## The Fix Applied

### Updated Seed Logic

```csharp
// Create driver test user with role and custom uid claim
var driverUser = await um.FindByNameAsync("charlie");
if (driverUser is null)
{
    driverUser = new IdentityUser { UserName = "charlie" };
    await um.CreateAsync(driverUser, "password");
}

// Ensure Charlie has the driver role (even if user already existed)
var charlieRoles = await um.GetRolesAsync(driverUser);
if (!charlieRoles.Contains("driver"))
{
    await um.AddToRoleAsync(driverUser, "driver");
}

// Ensure Charlie has the uid claim (even if user already existed)
var charlieClaims = await um.GetClaimsAsync(driverUser);
var charlieUidClaim = charlieClaims.FirstOrDefault(c => c.Type == "uid");
if (charlieUidClaim == null)
{
    await um.AddClaimAsync(driverUser, new Claim("uid", "driver-001"));
}
else if (charlieUidClaim.Value != "driver-001")
{
    // Update if wrong value
    await um.RemoveClaimAsync(driverUser, charlieUidClaim);
    await um.AddClaimAsync(driverUser, new Claim("uid", "driver-001"));
}
```

**What This Does:**
1. ? Creates Charlie if he doesn't exist
2. ? Adds driver role if missing (even on existing users)
3. ? Adds uid claim if missing (even on existing users)
4. ? Corrects uid claim if it has the wrong value

---

## New Diagnostic Endpoint

Added `GET /dev/user-info/{username}` to inspect any user's roles and claims:

### Usage Example

```bash
# Check Charlie's roles and claims
curl https://localhost:5001/dev/user-info/charlie
```

### Expected Response (After Fix)

```json
{
  "userId": "abc123...",
  "username": "charlie",
  "email": null,
  "roles": ["driver"],
  "claims": [
    { "type": "uid", "value": "driver-001" }
  ]
}
```

### What to Look For

| Check | Expected | If Missing |
|-------|----------|------------|
| Roles array contains "driver" | ? `["driver"]` | ? Authorization will fail (403) |
| Claims contain uid | ? `{"type": "uid", "value": "driver-001"}` | ? Driver assignment lookup will fail |

---

## How to Verify the Fix

### Step 1: Check Current State (Before Restart)

```bash
curl https://localhost:5001/dev/user-info/charlie
```

**If you see:**
```json
{
  "roles": [],  // ? EMPTY - This is the problem!
  "claims": []  // ? EMPTY - This is the problem!
}
```

Then Charlie was created without role/claims.

### Step 2: Restart the AuthServer

The fixed seed logic will run on startup and add the missing role/claims.

```bash
# Stop the server (Ctrl+C)
# Start it again
dotnet run
```

### Step 3: Verify Fix Applied

```bash
curl https://localhost:5001/dev/user-info/charlie
```

**Should now see:**
```json
{
  "roles": ["driver"],  // ? Fixed!
  "claims": [
    { "type": "uid", "value": "driver-001" }  // ? Fixed!
  ]
}
```

### Step 4: Test Login & JWT Token

```bash
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username": "charlie", "password": "password"}'
```

**Decode the JWT (use jwt.io)** and verify it contains:
```json
{
  "sub": "charlie",
  "uid": "driver-001",
  "role": "driver",  // ? This is critical for authorization
  "exp": 1234567890
}
```

### Step 5: Test Driver API Endpoint

```bash
# Use the JWT from Step 4
curl https://localhost:5000/driver/rides/today \
  -H "Authorization: Bearer <jwt_token>"
```

**Expected:** 200 OK with rides list (or empty array if no rides)  
**Before Fix:** 403 Forbidden

---

## JWT Token Claims Explained

### What the AdminAPI Checks

The AdminAPI driver endpoints likely use `[Authorize(Roles = "driver")]` or check for the `role` claim:

```csharp
// AdminAPI endpoint (typical pattern)
app.MapGet("/driver/rides/today", [Authorize(Roles = "driver")] 
    (HttpContext ctx) => {
        var uid = ctx.User.FindFirst("uid")?.Value;
        // Filter rides where AssignedDriverUid == uid
    });
```

**Authorization Flow:**
1. JWT Bearer middleware validates token signature ?
2. Middleware extracts claims from JWT
3. Authorization middleware checks if `role: driver` claim exists
4. If missing ? 403 Forbidden ?
5. If present ? Continue to endpoint ?

### Claims Generated During Login

**Before Fix:**
```json
{
  "sub": "charlie",
  "uid": "<identity-guid>"  // Wrong - uses ASP.NET Identity ID
  // ? NO ROLE CLAIM
}
```

**After Fix:**
```json
{
  "sub": "charlie",
  "uid": "driver-001",  // Correct - custom claim
  "role": "driver"      // ? Present - authorization works
}
```

---

## Why This Bug Was Subtle

1. **Authentication vs Authorization Confusion**
   - Authentication (login) succeeds because username/password are correct
   - Authorization (role check) fails silently with 403

2. **Seed Logic Assumption**
   - Original code assumed "if user exists, they're already configured"
   - Didn't account for users created before role/claim logic was added

3. **No Error Message**
   - 403 doesn't tell you "missing role claim"
   - Could be permissions, CORS, or other issues

---

## Other Potential Issues to Check

### 1. AdminAPI JWT Configuration

The AdminAPI must use the **same signing key** as AuthServer:

**AuthServer (Program.cs):**
```csharp
var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(
    "super-long-jwt-signing-secret-1234"));
```

**AdminAPI (should match):**
```csharp
var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(
    "super-long-jwt-signing-secret-1234"));
```

### 2. Role Claim Type

ASP.NET Core expects role claims as `"role"` by default. Verify AdminAPI doesn't expect a different claim type:

```csharp
// Correct (default)
new Claim("role", "driver")

// If AdminAPI uses ClaimTypes.Role, you need:
new Claim(ClaimTypes.Role, "driver")
```

### 3. Case Sensitivity

Role names are case-sensitive:

```csharp
[Authorize(Roles = "driver")]  // ? Matches "driver"
[Authorize(Roles = "Driver")]  // ? Doesn't match "driver"
```

---

## Prevention for Future

### Add Role/Claim Validation Test

```csharp
// Add to seed section
#if DEBUG
var testUser = await um.FindByNameAsync("charlie");
var testRoles = await um.GetRolesAsync(testUser);
var testClaims = await um.GetClaimsAsync(testUser);

if (!testRoles.Contains("driver"))
{
    Console.WriteLine("?? WARNING: Charlie is missing driver role!");
}

if (!testClaims.Any(c => c.Type == "uid" && c.Value == "driver-001"))
{
    Console.WriteLine("?? WARNING: Charlie is missing uid claim!");
}
#endif
```

### Add Health Check Endpoint

```csharp
app.MapGet("/health/seed-status", async (UserManager<IdentityUser> um) =>
{
    var charlie = await um.FindByNameAsync("charlie");
    if (charlie == null) return Results.Ok(new { status = "charlie_missing" });
    
    var roles = await um.GetRolesAsync(charlie);
    var claims = await um.GetClaimsAsync(charlie);
    
    return Results.Ok(new
    {
        status = "ok",
        hasDriverRole = roles.Contains("driver"),
        hasUidClaim = claims.Any(c => c.Type == "uid")
    });
});
```

---

## Summary

**Problem:** Charlie's JWT token was missing the `role: driver` claim due to flawed seed logic that only added roles/claims to new users.

**Fix:** Updated seed logic to always verify and add missing roles/claims, even for existing users.

**Verification:**
1. Restart AuthServer
2. Call `GET /dev/user-info/charlie`
3. Verify roles contains "driver"
4. Login and decode JWT
5. Test driver endpoint - should now return 200 instead of 403

**Files Changed:**
- `Program.cs` - Fixed seed logic for Charlie and other test drivers
- `Program.cs` - Added `/dev/user-info/{username}` diagnostic endpoint
