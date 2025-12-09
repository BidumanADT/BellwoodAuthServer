# AdminAPI 403 Fix - Implementation Guide

## Problem Identified

The AdminAPI JWT Bearer configuration was missing:
1. **NameClaimType mapping** - Needed to map "sub" claim to username
2. **Comprehensive event logging** - No way to see what was happening during authentication

## Solution Applied

Updated the JWT Bearer configuration in AdminAPI's `Program.cs` (around line 45) to:

1. ? Map `NameClaimType = "sub"` (tells ASP.NET where to find the username)
2. ? Added detailed authentication event logging:
   - `OnAuthenticationFailed` - Shows why token validation fails
   - `OnTokenValidated` - Shows successful validation and all claims
   - `OnChallenge` - Shows authentication challenges
   - `OnForbidden` - Shows **why 403 occurs** (this is the key!)

---

## ?? Testing Steps

### Step 1: Restart AdminAPI

Stop the AdminAPI if it's running, then restart it:

```powershell
cd C:\path\to\AdminAPI
dotnet run
```

**Expected output on startup:**
```
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: https://localhost:5206
```

### Step 2: Login as Charlie (Get Fresh Token)

Run the test script:

```powershell
cd C:\Users\sgtad\source\repos\BellwoodAuthServer
.\Scripts\test-charlie.ps1
```

**Copy the JWT token** from the output (it should show all green checkmarks).

### Step 3: Test the Driver Endpoint

**Option A: Using PowerShell**

```powershell
# Replace YOUR_TOKEN_HERE with the actual token from Step 2
$token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJjaGFybGllIiwicm9sZSI6ImRyaXZlciIsInVpZCI6ImRyaXZlci0wMDEiLCJleHAiOjE3NjUyNTcxNTV9.bhpTxFS3CV5YK98qNwTe-vHd-H_sEH106O4UbksROmk"

# Bypass SSL for localhost
[ServerCertificateValidationCallback]::Ignore()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Call the driver endpoint
$headers = @{
    Authorization = "Bearer $token"
}

try {
    $response = Invoke-RestMethod -Uri "https://localhost:5206/driver/rides/today" `
        -Headers $headers `
        -Method GET
    
    Write-Host "? SUCCESS! Status: 200" -ForegroundColor Green
    Write-Host "Rides returned:" -ForegroundColor Cyan
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "? FAILED! Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
```

**Option B: Using curl**

```bash
curl -k https://localhost:5206/driver/rides/today \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

---

## ?? What to Look For

### In AdminAPI Console Output

#### ? SUCCESS - You'll see:

```
? Token VALIDATED successfully
   User: charlie
   Claims: sub=charlie, role=driver, uid=driver-001, exp=1765257155
   IsAuthenticated: True
   ? Role found: driver
```

Then the endpoint will return **200 OK** with ride data.

#### ? FAILURE - You'll see one of these:

**Scenario 1: Token signature invalid (wrong key)**
```
?? Authentication FAILED: SecurityTokenInvalidSignatureException
   Message: IDX10503: Signature validation failed...
```
**Fix:** Keys don't match between AuthServer and AdminAPI. Double-check the JWT key.

**Scenario 2: Token valid but 403 Forbidden**
```
? Token VALIDATED successfully
   User: charlie
   Claims: sub=charlie, role=driver, uid=driver-001
   IsAuthenticated: True
   ? Role found: driver

?? Authorization FORBIDDEN (403)
   User: charlie
   IsAuthenticated: True
   Roles: driver
```
**Fix:** This would mean the `[Authorize(Policy = "DriverOnly")]` policy isn't recognizing the role. Check the authorization configuration.

**Scenario 3: No role claim found**
```
? Token VALIDATED successfully
   User: charlie
   Claims: sub=charlie, uid=driver-001
   IsAuthenticated: True
   ??  NO ROLE CLAIM FOUND!

?? Authorization FORBIDDEN (403)
   User: charlie
   IsAuthenticated: True
   Roles: NONE
```
**Fix:** Token doesn't have role claim. Charlie's user record in AuthServer is missing the driver role.

---

## ?? Expected Results

### Successful Response (200 OK)

```json
[
  {
    "id": "abc123...",
    "pickupDateTime": "2025-01-04T10:00:00Z",
    "pickupLocation": "Langham Hotel",
    "dropoffLocation": "Midway Airport",
    "passengerName": "Jordan Chen",
    "passengerPhone": "312-555-6666",
    "status": "Scheduled"
  },
  {
    "id": "def456...",
    "pickupDateTime": "2025-01-06T14:00:00Z",
    "pickupLocation": "O'Hare FBO",
    "dropoffLocation": "Peninsula Hotel, Chicago",
    "passengerName": "Emma Watson",
    "passengerPhone": "312-555-8888",
    "status": "Scheduled"
  }
]
```

**This means:**
- ? Authentication succeeded
- ? Authorization succeeded
- ? Charlie can see his assigned rides
- ? The driver app will work!

---

## ?? Troubleshooting

### Issue 1: Still Getting 403

**Check the AdminAPI console output carefully.** The new logging will tell you exactly what's wrong:

1. If you see "Authentication FAILED" - Token is invalid
2. If you see "Token VALIDATED" but "Authorization FORBIDDEN" - Role problem
3. If you see "NO ROLE CLAIM FOUND" - AuthServer problem

### Issue 2: Token Expired

Tokens expire after 1 hour. If you see:

```
?? Authentication FAILED: SecurityTokenExpiredException
```

**Fix:** Get a fresh token by running `.\Scripts\test-charlie.ps1` again.

### Issue 3: Connection Refused

```
? FAILED! Unable to connect to the remote server
```

**Fix:** Make sure AdminAPI is running on port 5206:
```powershell
cd C:\path\to\AdminAPI
dotnet run
```

---

## ?? Testing in the Driver App

Once the PowerShell test succeeds (returns 200), test in the actual driver app:

1. **Clean the app** (if it cached a bad token):
   - Android: Uninstall and reinstall the driver app
   - Or: Clear app data in Android settings

2. **Login as Charlie**:
   - Username: `charlie`
   - Password: `password`

3. **Check Today's Rides**:
   - Should see the 2 rides assigned to Charlie
   - No more 403 errors!

---

## ?? What Changed

### Before (Missing Features)

```csharp
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = false,
        ValidateAudience = false,
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = signingKey,
        ValidateLifetime = true,
        ClockSkew = TimeSpan.Zero,
        RoleClaimType = "role"  // Had this
        // ? Missing NameClaimType
        // ? No event logging
    };
});
```

### After (Complete Configuration)

```csharp
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = false,
        ValidateAudience = false,
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = signingKey,
        ValidateLifetime = true,
        ClockSkew = TimeSpan.Zero,
        RoleClaimType = "role",      // ? Maps role claim
        NameClaimType = "sub"        // ? Maps username claim
    };
    
    // ? Comprehensive event logging
    options.Events = new JwtBearerEvents
    {
        OnAuthenticationFailed = context => { /* log failures */ },
        OnTokenValidated = context => { /* log success + claims */ },
        OnChallenge = context => { /* log challenges */ },
        OnForbidden = context => { /* log 403s with details */ }
    };
});
```

---

## ? Success Criteria

You know it's working when:

1. ? `.\Scripts\test-charlie.ps1` shows all green checkmarks
2. ? AdminAPI console shows "Token VALIDATED successfully"
3. ? AdminAPI console shows "? Role found: driver"
4. ? PowerShell test returns **200 OK** with ride data
5. ? No "Authorization FORBIDDEN (403)" message in console
6. ? Driver app shows "Today's Rides" with Charlie's assignments

---

## ?? Next Steps After Success

1. **Remove console logging in production** (or change to logger instead of Console.WriteLine)
2. **Test with other drivers** to ensure the fix works universally
3. **Test all driver endpoints** (not just /today):
   - GET `/driver/rides/{id}`
   - POST `/driver/rides/{id}/status`
   - POST `/driver/location/update`

---

## Summary

The fix was simple but critical:

1. ? Added `NameClaimType = "sub"` to properly map username
2. ? Added comprehensive event logging to debug auth issues
3. ? The `RoleClaimType = "role"` you already had was correct

**The logging will now show you EXACTLY why authentication or authorization fails**, making future debugging much easier!
