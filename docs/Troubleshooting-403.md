# Quick Troubleshooting Checklist - Driver 403 Errors

## Problem
Driver can login but gets 403 Forbidden when accessing driver-only endpoints.

## Root Cause
JWT token is missing the `role: driver` claim needed for authorization.

---

## Step-by-Step Diagnosis

### 1. Check User Configuration (5 seconds)

**Run this:**
```bash
curl https://localhost:5001/dev/user-info/charlie
```

**What to look for:**

? **GOOD - User is configured correctly:**
```json
{
  "roles": ["driver"],
  "claims": [{"type": "uid", "value": "driver-001"}],
  "diagnostics": {
    "hasDriverRole": true,
    "hasUidClaim": true,
    "canAccessDriverEndpoints": true,
    "warning": null
  }
}
```

? **BAD - User is missing role (causes 403):**
```json
{
  "roles": [],  // ?? EMPTY!
  "claims": [],
  "diagnostics": {
    "hasDriverRole": false,  // ?? THIS CAUSES 403!
    "warning": "?? User missing 'driver' role - will get 403 on driver endpoints"
  }
}
```

---

### 2. Fix Missing Role/Claims

**Option A: Restart the server (recommended)**
The fixed seed logic will automatically add missing roles/claims:

```bash
# Stop server (Ctrl+C)
dotnet run
```

Then repeat Step 1 to verify.

**Option B: Use Admin API**
```bash
curl -X POST https://localhost:5001/api/admin/users/charlie/uid \
  -H "Content-Type: application/json" \
  -d '{"userUid": "driver-001"}'
```

**Option C: Manual database fix**
```sql
-- Add driver role
INSERT INTO AspNetUserRoles (UserId, RoleId)
SELECT u.Id, r.Id 
FROM AspNetUsers u, AspNetRoles r
WHERE u.UserName = 'charlie' AND r.Name = 'driver';

-- Add uid claim
INSERT INTO AspNetUserClaims (UserId, ClaimType, ClaimValue)
SELECT Id, 'uid', 'driver-001'
FROM AspNetUsers
WHERE UserName = 'charlie';
```

---

### 3. Verify JWT Token

**Login to get a token:**
```bash
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username": "charlie", "password": "password"}'
```

**Copy the `accessToken` value and decode it at https://jwt.io**

? **GOOD - Token has role claim:**
```json
{
  "sub": "charlie",
  "uid": "driver-001",
  "role": "driver",  // ? Authorization will work
  "exp": 1234567890
}
```

? **BAD - Token missing role claim:**
```json
{
  "sub": "charlie",
  "uid": "abc123...",
  // ? NO "role" CLAIM - Authorization will fail with 403
  "exp": 1234567890
}
```

---

### 4. Test Driver Endpoint

**Use the JWT token from Step 3:**
```bash
curl https://localhost:5000/driver/rides/today \
  -H "Authorization: Bearer YOUR_JWT_TOKEN_HERE"
```

**Expected Results:**

| Status | Meaning | Next Step |
|--------|---------|-----------|
| 200 OK | ? Working! Role claim present | Done |
| 401 Unauthorized | Token expired or invalid signature | Get new token (Step 3) |
| 403 Forbidden | ? Missing role claim | Go back to Step 1 |

---

## Common Issues & Solutions

### Issue 1: User Doesn't Exist
**Symptom:** `/dev/user-info/charlie` returns 404

**Fix:**
```bash
# Restart server - seed logic will create Charlie
dotnet run
```

### Issue 2: Role Added But Token Still Wrong
**Symptom:** `/dev/user-info/charlie` shows `hasDriverRole: true` but JWT still has no role

**Fix:** Get a NEW token - old tokens are cached by client
```bash
# Login again to get fresh token
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username": "charlie", "password": "password"}'
```

### Issue 3: Wrong UID Value
**Symptom:** JWT has `uid: "abc-123..."` instead of `uid: "driver-001"`

**Fix:** The seed logic will correct this on next restart
```bash
dotnet run
```

### Issue 4: AdminAPI Still Returns 403
**Symptom:** Token looks correct but AdminAPI rejects it

**Possible Causes:**
1. **Different signing key** - AuthServer and AdminAPI must use same secret
2. **Role claim name mismatch** - AdminAPI expects `ClaimTypes.Role` instead of `"role"`
3. **CORS issue** - Preflight request blocked (check for OPTIONS 403)

**Check AdminAPI logs:**
```bash
# Look for authentication/authorization errors
tail -f logs/adminapi.log
```

---

## Quick Reference

### Diagnostic Endpoint
```bash
GET /dev/user-info/{username}
```

### Seed Endpoint (Re-seed if needed)
```bash
POST /dev/seed-drivers
```

### Login Endpoint
```bash
POST /login
POST /api/auth/login
POST /connect/token
```

### Admin User Management
```bash
POST /api/admin/users/drivers          # Create driver user
GET /api/admin/users/drivers           # List driver users
PUT /api/admin/users/{username}/uid    # Update uid
GET /api/admin/users/by-uid/{userUid}  # Find by uid
DELETE /api/admin/users/drivers/{username}  # Delete driver
```

---

## Success Criteria

All of these should be TRUE:
- [ ] `/dev/user-info/charlie` shows `"hasDriverRole": true`
- [ ] `/dev/user-info/charlie` shows `"hasUidClaim": true`
- [ ] JWT decoded at jwt.io shows `"role": "driver"`
- [ ] JWT shows `"uid": "driver-001"`
- [ ] `GET /driver/rides/today` returns 200 (not 403)

If all checks pass but still getting 403, the issue is likely in AdminAPI authorization configuration, not AuthServer.
