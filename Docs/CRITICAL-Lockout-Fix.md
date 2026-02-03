# ?? CRITICAL UPDATE - Lockout Implementation Issue

**Date:** February 2, 2026  
**Discovery:** Login lockout verification  
**Status:** ?? **LOCKOUT MAY NOT BLOCK LOGIN**

---

## ?? Critical Finding

### **Login Implementation Uses CheckPasswordAsync**

**Current Code (Program.cs, line ~365):**
```csharp
var user = await um.FindByNameAsync(req.Username);
if (user is null || !(await um.CheckPasswordAsync(user, req.Password)))
{
    return Results.Unauthorized();
}
```

### **Problem**

`UserManager.CheckPasswordAsync()` **does NOT automatically enforce lockout!**

**From Microsoft Docs:**
> `CheckPasswordAsync` - Returns a flag indicating whether the given password is valid for the specified user.
> 
> **This method does NOT check lockout status.**

**To enforce lockout, you must use:**
- `SignInManager.PasswordSignInAsync()` (recommended)
- OR manually check `LockoutEnd` before allowing login

---

## ?? Impact Assessment

### **Current Disable Behavior**

**AdminUserProvisioningController sets:**
```csharp
user.LockoutEnabled = true;
user.LockoutEnd = DateTimeOffset.UtcNow.AddYears(100);
```

**But login endpoint:**
```csharp
// ? This will succeed even if user is locked out!
await um.CheckPasswordAsync(user, req.Password)
```

**Result:** ?? **Disabled users CAN still login and get tokens!**

---

## ? Solution Options

### **Option A: Use SignInManager (RECOMMENDED)**

**Pros:**
- Automatic lockout enforcement
- Follows ASP.NET Identity best practices
- Handles all edge cases

**Cons:**
- Requires adding cookies middleware (we're using JWT only)
- More complex

**Implementation:**
```csharp
// Add to builder.Services
builder.Services
    .AddIdentityCore<IdentityUser>(...)
    .AddSignInManager();  // ? Already added!

// In login endpoint
app.MapPost("/login", async (
    UserManager<IdentityUser> um,
    SignInManager<IdentityUser> sm,  // ? Add this
    RefreshTokenStore store,
    LoginRequest? req) =>
{
    var user = await um.FindByNameAsync(req.Username);
    if (user is null)
    {
        return Results.Unauthorized();
    }

    // ? This enforces lockout automatically
    var result = await sm.CheckPasswordSignInAsync(user, req.Password, lockoutOnFailure: false);
    
    if (!result.Succeeded)
    {
        if (result.IsLockedOut)
        {
            return Results.Problem(
                detail: "User account is disabled.",
                statusCode: 403);
        }
        return Results.Unauthorized();
    }

    // Continue with token generation...
});
```

---

### **Option B: Manual Lockout Check (QUICK FIX)**

**Pros:**
- Minimal code change
- No architectural changes

**Cons:**
- Manual implementation (could miss edge cases)
- Not following best practices

**Implementation:**
```csharp
app.MapPost("/login", async (
    UserManager<IdentityUser> um,
    RefreshTokenStore store,
    LoginRequest? req) =>
{
    var user = await um.FindByNameAsync(req.Username);
    if (user is null)
    {
        return Results.Unauthorized();
    }

    // ? Check lockout BEFORE password
    if (await um.IsLockedOutAsync(user))
    {
        return Results.Problem(
            detail: "User account is disabled.",
            statusCode: 403);
    }

    // Check password
    if (!(await um.CheckPasswordAsync(user, req.Password)))
    {
        return Results.Unauthorized();
    }

    // Continue with token generation...
});
```

---

## ?? Recommended Implementation

### **Use Option A (SignInManager) with JWT-friendly approach**

**Why:**
- Already have `AddSignInManager()` configured
- `CheckPasswordSignInAsync` designed for this
- Proper lockout enforcement
- No cookies needed (we're JWT-only)

**Full Implementation:**

```csharp
app.MapPost("/login", 
    async (
    UserManager<IdentityUser> um,
    SignInManager<IdentityUser> sm,  // ? Add SignInManager
    RefreshTokenStore store,
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

    // Find user
    var user = await um.FindByNameAsync(req.Username);
    if (user is null)
    {
        // Don't leak whether user exists
        return Results.Unauthorized();
    }

    // ? Check password and lockout in one call
    var signInResult = await sm.CheckPasswordSignInAsync(
        user, 
        req.Password, 
        lockoutOnFailure: false  // We don't want to lock out on failed attempts
    );

    // Handle sign-in result
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
        return Results.Unauthorized();
    }

    // ? User authenticated and not locked out - generate token
    var claims = new List<Claim>
    {
        new Claim("sub", user.UserName!),
        new Claim("uid", user.Id),
        new Claim("userId", user.Id)
    };
    
    // ... rest of token generation unchanged ...
    
}).AllowAnonymous();
```

**Apply same fix to `/api/auth/login` endpoint**

---

## ?? Updated Implementation Plan

### **Phase 1: Critical Fixes (DO IMMEDIATELY)**

#### **1a. Fix Lockout Enforcement (CRITICAL)**
- Add SignInManager to login endpoints
- Use `CheckPasswordSignInAsync` instead of `CheckPasswordAsync`
- Handle `IsLockedOut` result
- Time: 15 minutes

#### **1b. Fix Role Case Normalization**
- Add `.ToLowerInvariant()` to NormalizeRoles
- Add normalization to EnsureRolesExistAsync
- Time: 5 minutes

**Total Phase 1 Time: 20 minutes**

---

### **Phase 2: Testing (CRITICAL)**

#### **Test Lockout Enforcement:**
```http
# Create test user
POST /admin/users
{
  "email": "lockouttest@example.com",
  "tempPassword": "Test123!",
  "roles": ["booker"]
}

# Verify login works
POST /login
{
  "username": "lockouttest@example.com",
  "password": "Test123!"
}
# ? Should succeed with token

# Disable user
PUT /admin/users/{userId}/disable

# Verify login blocked
POST /login
{
  "username": "lockouttest@example.com",
  "password": "Test123!"
}
# ? Should return 403 Forbidden with "Account Disabled" message

# Enable user
PUT /admin/users/{userId}/enable

# Verify login works again
POST /login
{
  "username": "lockouttest@example.com",
  "password": "Test123!"
}
# ? Should succeed with token
```

---

### **Phase 3: Route Decision (AS PLANNED)**

Proceed with Option B (rename route) as discussed.

---

### **Phase 4: Optional (AS PLANNED)**

Add enable endpoint.

---

## ? Updated Priority

| Task | Original Priority | New Priority | Reason |
|------|------------------|--------------|--------|
| Lockout fix | Not identified | ?? CRITICAL | Security issue |
| Role normalization | MEDIUM | ?? HIGH | Data consistency |
| Route decision | MEDIUM | ?? MEDIUM | Design issue |
| Enable endpoint | OPTIONAL | ?? MEDIUM | Completes feature |

---

## ?? Action Required

**Before ANY deployment:**
1. ? Fix lockout enforcement in both login endpoints
2. ? Test disable/enable cycle thoroughly
3. ? Fix role normalization
4. ?? Then proceed with route decision

---

**This is a security issue - disabled users can currently still login!**

---

*Updated plan based on lockout verification. Ready for immediate implementation.* ???
