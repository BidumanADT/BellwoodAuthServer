# ??? Route Analysis - Complete Mapping

**Date:** February 2, 2026  
**Purpose:** Identify safest route renaming strategy  
**Status:** Ready for decision

---

## ?? Current Route Mapping

### **Controller 1: AdminUsersController**

```csharp
[Route("api/admin/users")]
[Authorize(Policy = "AdminOnly")]
public class AdminUsersController : ControllerBase
```

**Endpoints:**
| Method | Route | Full Path | Purpose |
|--------|-------|-----------|---------|
| POST | `drivers` | `/api/admin/users/drivers` | Create driver user |
| PUT | `{username}/uid` | `/api/admin/users/{username}/uid` | Update driver UID |
| GET | `drivers` | `/api/admin/users/drivers` | List driver users |
| GET | *(none)* | `/api/admin/users` | List all users (Phase 2) |
| GET | `by-uid/{userUid}` | `/api/admin/users/by-uid/{userUid}` | Get user by UID |
| DELETE | `drivers/{username}` | `/api/admin/users/drivers/{username}` | Delete driver |

---

### **Controller 2: AdminUserProvisioningController**

```csharp
[Route("admin/users")]  // ?? Missing "api/" prefix
[Authorize(Policy = "AdminOnly")]
public class AdminUserProvisioningController : ControllerBase
```

**Endpoints:**
| Method | Route | Full Path | Purpose |
|--------|-------|-----------|---------|
| GET | *(none)* | `/admin/users` | List users (paginated) |
| POST | *(none)* | `/admin/users` | Create user |
| PUT | `{userId}/roles` | `/admin/users/{userId}/roles` | Update user roles |
| PUT | `{userId}/disable` | `/admin/users/{userId}/disable` | Disable user |

---

## ?? Conflict Analysis

### **No Direct Conflicts (Different Prefixes)**

| AdminUsersController | AdminUserProvisioningController | Conflict? |
|---------------------|--------------------------------|-----------|
| `/api/admin/users` | `/admin/users` | ? No (different prefix) |
| `/api/admin/users/drivers` | N/A | ? No |
| `/api/admin/users/{username}/uid` | `/admin/users/{userId}/roles` | ? No (different paths) |

**Technical Verdict:** No runtime route conflicts.

**Design Verdict:** Confusing and inconsistent.

---

## ?? Recommended Route Strategy

### **Option: Rename to Clear Provisioning Namespace**

**Change AdminUserProvisioningController route from:**
```csharp
[Route("admin/users")]
```

**To:**
```csharp
[Route("api/admin/provisioning")]
```

---

## ?? Exact Changes Needed

### **File: Controllers/AdminUserProvisioningController.cs**

**Line 9 - Change Route Attribute:**

**BEFORE:**
```csharp
[Route("admin/users")]
```

**AFTER:**
```csharp
[Route("api/admin/provisioning")]
```

**That's it! One line change.**

---

## ??? New Route Mapping After Fix

### **AdminUsersController** (Unchanged)
| Endpoint | Path |
|----------|------|
| List all users | `GET /api/admin/users` |
| List drivers | `GET /api/admin/users/drivers` |
| Create driver | `POST /api/admin/users/drivers` |
| Update UID | `PUT /api/admin/users/{username}/uid` |
| Get by UID | `GET /api/admin/users/by-uid/{userUid}` |
| Delete driver | `DELETE /api/admin/users/drivers/{username}` |

### **AdminUserProvisioningController** (After Fix)
| Endpoint | Path |
|----------|------|
| List users (paginated) | `GET /api/admin/provisioning` |
| Create user | `POST /api/admin/provisioning` |
| Update roles | `PUT /api/admin/provisioning/{userId}/roles` |
| Disable user | `PUT /api/admin/provisioning/{userId}/disable` |

---

## ? Why This Works

### **Clear Separation:**
- **`/api/admin/users`** ? Driver-focused user management (existing workflows)
- **`/api/admin/provisioning`** ? General user lifecycle (new Codex features)

### **Consistent Prefix:**
- Both use `api/` prefix ?
- Both use `admin/` namespace ?
- Different final segments (users vs provisioning) ?

### **No Breaking Changes:**
- AdminAPI calls to `/api/admin/users` unaffected ?
- Portal calls to driver endpoints unaffected ?
- Only affects new Codex endpoints (not yet in use) ?

---

## ?? Impact on Existing Clients

### **AdminAPI**
**Current Calls (if any):**
- Unknown if AdminAPI proxies provisioning endpoints yet
- If yes, update proxy to call `/api/admin/provisioning`

**Action:** Check AdminAPI codebase for any calls to `admin/users` (without `api/`)

### **Admin Portal**
**Current Calls (if any):**
- Portal should call AdminAPI, not AuthServer directly
- If Portal calls `admin/users` directly, update to `/api/admin/provisioning`

**Action:** Check Portal codebase for direct AuthServer calls

### **Test Scripts**
**Update needed:**
- Any test scripts calling `/admin/users` ? `/api/admin/provisioning`

---

## ?? Implementation Steps

### **Step 1: Update Controller Route**
```csharp
// File: Controllers/AdminUserProvisioningController.cs
// Line 9

[Route("api/admin/provisioning")]  // Changed from "admin/users"
```

### **Step 2: Update Documentation**
- Update `Docs/Alpha-AdminUserProvisioning.md` (if exists)
- Update any API documentation
- Update test scripts

### **Step 3: Communication**
- Notify AdminAPI team of route change
- Notify Portal team of route change
- Update any integration documentation

### **Step 4: Testing**
```http
# Test all provisioning endpoints with new route
GET /api/admin/provisioning
POST /api/admin/provisioning
PUT /api/admin/provisioning/{userId}/roles
PUT /api/admin/provisioning/{userId}/disable
```

---

## ?? Estimated Impact

| Task | Time | Risk |
|------|------|------|
| Change controller route | 1 min | None (one line) |
| Build & verify | 2 min | Low |
| Update documentation | 5 min | None |
| Test endpoints | 5 min | Low |
| Notify teams | 5 min | Low |
| **TOTAL** | **18 min** | **LOW** |

---

## ?? Final Recommendation

### **Do This Now (Before Alpha):**

**1. Change Route (1 line):**
```csharp
[Route("api/admin/provisioning")]
```

**2. Test Endpoints**
```http
GET /api/admin/provisioning
POST /api/admin/provisioning
```

**3. Update Docs**
- API documentation
- Test scripts
- Integration guides

**4. Communicate**
- Email AdminAPI team
- Email Portal team
- Update project wiki

---

## ?? Future Consideration (Post-Alpha)

### **Potential Controller Consolidation**

**Long-term goal:** Merge into single user management controller

**Timeline:** Next sprint or when tech debt prioritized

**Benefits:**
- Single source of truth
- Cleaner API design
- Easier to document

**For now:** Keep separate, rename for clarity ?

---

## ? Decision Summary

**Recommendation:** Change `AdminUserProvisioningController` route to `api/admin/provisioning`

**Justification:**
- 1 line change
- No breaking changes (new endpoints)
- Clear separation of concerns
- Consistent API prefix
- Low risk, high clarity

**Ready to implement:** YES ?

---

*Route analysis complete. Ready for one-line fix!* ????
