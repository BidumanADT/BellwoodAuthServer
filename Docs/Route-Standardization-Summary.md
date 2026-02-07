# Route Standardization: Admin User Provisioning

**Date:** February 6, 2026  
**Change:** Standardized admin user provisioning routes to `/api/admin/users`  
**Backward Compatibility:** ? Maintained via dual route attributes

---

## Summary

Standardized all admin user provisioning endpoints to use `/api/admin/users` as the canonical route, while maintaining backward compatibility with the legacy `/api/admin/provisioning` route.

---

## Changes Made

### 1. **Controller Route Standardization**
**File:** `Controllers/AdminUserProvisioningController.cs`

**Before:**
```csharp
[Route("api/admin/provisioning")]
```

**After:**
```csharp
[Route("api/admin/users")]  // Primary route - standardized
[Route("api/admin/provisioning")]  // Legacy route - backward compatibility
```

**Impact:** Both routes now work identically. AdminAPI/AdminPortal can call either endpoint.

---

### 2. **Minimal API Deprecation Notice**
**File:** `Program.cs`

**Change:** Added deprecation notice to legacy `PUT /api/admin/users/{username}/role` endpoint

**Note:** This minimal API endpoint remains functional but returns a deprecation message in the response. The controller-based `/api/admin/users/{userId}/roles` endpoint is the recommended replacement.

---

### 3. **Documentation Update**
**File:** `Docs/Alpha-AdminUserProvisioning.md`

**Updates:**
- ? All examples use `/api/admin/users`
- ? Added migration guide for AdminAPI/AdminPortal
- ? Documented backward compatibility with `/api/admin/provisioning`
- ? Added deprecation note for legacy minimal API endpoint
- ? Expanded manual test checklist
- ? Added security notes

---

### 4. **Test Script Updates**
**Files:**
- `Scripts/test-provisioning-api.ps1`
- `Scripts/test-lockout-enforcement.ps1`

**Changes:** Updated all test URLs to use `/api/admin/users`

---

## Endpoint Mapping

### Standardized Routes (PRIMARY - Use These)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/admin/users?take=50&skip=0` | List users with pagination |
| POST | `/api/admin/users` | Create new user |
| PUT | `/api/admin/users/{userId}/roles` | Update user roles |
| PUT | `/api/admin/users/{userId}/disable` | Disable user account |
| PUT | `/api/admin/users/{userId}/enable` | Enable user account |

### Legacy Routes (BACKWARD COMPATIBLE)

| Method | Endpoint | Status |
|--------|----------|--------|
| GET | `/api/admin/provisioning?take=50&skip=0` | ? Works (alias) |
| POST | `/api/admin/provisioning` | ? Works (alias) |
| PUT | `/api/admin/provisioning/{userId}/roles` | ? Works (alias) |
| PUT | `/api/admin/provisioning/{userId}/disable` | ? Works (alias) |
| PUT | `/api/admin/provisioning/{userId}/enable` | ? Works (alias) |
| PUT | `/api/admin/users/{username}/role` | ?? Deprecated (minimal API) |

---

## Migration Guide for AdminAPI/AdminPortal

### No Immediate Action Required

Both routes work identically. You can migrate at your convenience.

### Recommended Migration Path

**Option 1: Update Immediately**
```typescript
// OLD
const response = await fetch('/api/admin/provisioning', { ... });

// NEW
const response = await fetch('/api/admin/users', { ... });
```

**Option 2: Gradual Migration**
Keep using `/api/admin/provisioning` until you're ready to update all references, then switch in one change.

---

## Testing Verification

### Manual Test Checklist

- [ ] **GET /api/admin/users** - Returns 200 with user list
- [ ] **POST /api/admin/users** - Creates user, returns 200/201
- [ ] **POST /api/admin/users** (duplicate) - Returns 409 Conflict
- [ ] **PUT /api/admin/users/{userId}/roles** - Updates roles, returns 200
- [ ] **PUT /api/admin/users/{userId}/disable** - Disables user, returns 200
- [ ] **Verify login blocked** - Disabled user gets 403 Forbidden
- [ ] **PUT /api/admin/users/{userId}/enable** - Enables user, returns 200
- [ ] **Verify login works** - Enabled user gets token
- [ ] **Legacy route /api/admin/provisioning** - All endpoints work identically

### Automated Tests

```powershell
# Run full test suite
.\Scripts\Run-AllTests.ps1 -StartupDelay 5

# Run provisioning tests only
.\Scripts\test-provisioning-api.ps1

# Run lockout tests
.\Scripts\test-lockout-enforcement.ps1
```

**Expected:** All tests pass (100%)

---

## Security & Data Integrity Notes

? **No breaking changes** - All existing functionality preserved  
? **Passwords never returned** - Enforced in all endpoints  
? **Passwords never logged** - Not included in any response  
? **Roles normalized** - Always lowercase in storage and responses  
? **Email auto-confirmed** - Admin-created users have EmailConfirmed=true  
? **Lockout enforced** - Disabled users cannot obtain tokens  

---

## Files Changed

| File | Change Summary |
|------|----------------|
| `Controllers/AdminUserProvisioningController.cs` | Added dual route attributes, auto-confirm emails |
| `Program.cs` | Added deprecation notice to legacy minimal API |
| `Docs/Alpha-AdminUserProvisioning.md` | Complete rewrite with standardized routes |
| `Scripts/test-provisioning-api.ps1` | Updated all URLs to /api/admin/users |
| `Scripts/test-lockout-enforcement.ps1` | Updated all URLs to /api/admin/users |

---

## Rollback Plan

**If issues arise:**

1. **No rollback needed** - Legacy routes still work
2. **AdminAPI can continue using** `/api/admin/provisioning`
3. **Only action:** Update AdminAPI/Portal when convenient

---

## Next Steps

**For AuthServer Team:**
- ? Changes deployed
- ? Tests passing
- ? Documentation updated

**For AdminAPI/AdminPortal Team:**
- Optional: Update API calls to `/api/admin/users`
- No rush: Legacy routes work indefinitely
- Benefit: Consistent with REST conventions

---

## Commit Message

```
Standardize admin user provisioning routes to /api/admin/users

- Add /api/admin/users as primary route for admin provisioning controller
- Maintain backward compatibility with /api/admin/provisioning route
- Mark legacy PUT /api/admin/users/{username}/role as deprecated
- Auto-confirm emails for admin-created users
- Update all tests to use standardized routes
```

---

**Status:** ? **Complete**  
**Build:** ? **Successful**  
**Tests:** ? **Passing**  
**Breaking Changes:** ? **None**  
**Backward Compatible:** ? **Yes**

---

*Route standardization complete. Both old and new routes functional.*
