# Quick Reference - Phase 1 & 2 Changes

**For developers needing quick answers about AuthServer changes**

---

## ?? What Changed?

### Phase 1: JWT Now Contains `userId` Claim

**Before Phase 1:**
```json
{
  "sub": "alice",
  "uid": "guid-xxx",
  "role": "admin"
}
```

**After Phase 1:**
```json
{
  "sub": "alice",
  "uid": "guid-xxx",
  "userId": "guid-xxx",  // ? NEW
  "role": "admin"
}
```

### Phase 2: Dispatcher Role Added

**Dispatcher JWT:**
```json
{
  "sub": "diana",
  "uid": "guid-xxx",
  "userId": "guid-xxx",
  "role": "dispatcher",  // ? NEW ROLE
  "email": "diana.dispatcher@bellwood.example"
}
```

---

## ?? Why These Changes?

### Phase 1: userId Claim
- **Consistent format:** Always an Identity GUID
- **Audit tracking:** Use for `CreatedByUserId` field
- **Driver support:** Drivers keep custom `uid` but have Identity GUID in `userId`

### Phase 2: Dispatcher Role
- **Separation of duties:** Operational staff vs administrators
- **Least privilege:** Dispatchers see bookings but NOT billing
- **RBAC foundation:** Enables role-based access control

---

## ?? Driver Tokens Special Case

**Driver Token:**
```json
{
  "sub": "charlie",
  "uid": "driver-001",           // Custom UID for assignment
  "userId": "a1b2c3d4-...",      // Identity GUID for audit
  "role": "driver"
}
```

**Why different?**
- `uid`: Used to match `AssignedDriverUid` in bookings
- `userId`: Used for audit trail (`CreatedByUserId`)

---

## ?? How to Use in AdminAPI

### Phase 1: Audit Tracking
```csharp
// Get userId for audit tracking
var userId = User.FindFirstValue("userId");

// Fallback for backward compatibility
if (string.IsNullOrEmpty(userId))
{
    userId = User.FindFirstValue("uid");
}

// Store in CreatedByUserId
booking.CreatedByUserId = userId;
```

### Phase 2: Role-Based Authorization
```csharp
// Check if user is dispatcher
if (User.IsInRole("dispatcher"))
{
    // Mask billing fields
    booking.PaymentMethodId = null;
    booking.BillingAmount = null;
}

// Or use policies
[Authorize(Policy = "StaffOnly")]
public async Task<IActionResult> GetBookings()
{
    // Both admin and dispatcher can access
}

[Authorize(Policy = "AdminOnly")]
public async Task<IActionResult> GetBillingReport()
{
    // Only admin can access
}
```

---

## ?? Authorization Policies (Phase 2)

### AdminOnly
- **Requires:** `admin` role
- **Use for:** User management, billing, sensitive operations

### StaffOnly
- **Requires:** `admin` OR `dispatcher` role
- **Use for:** Booking/quote management, driver assignment

### DriverOnly
- **Requires:** `driver` role
- **Use for:** Driver-specific endpoints

### BookerOnly
- **Requires:** `booker` role
- **Use for:** Passenger-specific endpoints

---

## ?? User Roles

| Role | Purpose | Test User | Phase |
|------|---------|-----------|-------|
| `admin` | Full system access | alice, bob | Phase 1 |
| `dispatcher` | Operational staff | diana | Phase 2 ? |
| `booker` | Create bookings | chris | Phase 1 |
| `driver` | Drive assignments | charlie | Phase 1 |

---

## ?? Quick Test

### Phase 1: Test userId Claim
```bash
# Login
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"password"}'

# Decode token at jwt.io
# Look for "userId" claim
```

### Phase 2: Test Dispatcher Role
```bash
# Login as dispatcher
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"diana","password":"password"}'

# Try admin endpoint (should fail)
curl -X GET https://localhost:5001/api/admin/users/drivers \
  -H "Authorization: Bearer <diana-token>"
# Expected: 403 Forbidden
```

---

## ?? Phase 2: Role Assignment

### Change a User's Role
```bash
# Admin changes bob to dispatcher
curl -X PUT https://localhost:5001/api/admin/users/bob/role \
  -H "Authorization: Bearer <admin-token>" \
  -H "Content-Type: application/json" \
  -d '{"role":"dispatcher"}'
```

### Valid Roles
- `admin`
- `dispatcher`
- `booker`
- `driver`

---

## ?? Files Changed

### Phase 1
- `Program.cs` - Both login endpoints updated
- `Controllers/TokenController.cs` - OAuth endpoint updated
- `Data/Phase2RolePreparation.cs` - New file (Phase 2 ready)

### Phase 2
- `Program.cs` - Activated dispatcher role, added policies
- `Controllers/AdminUsersController.cs` - Applied AdminOnly policy
- New endpoint: `PUT /api/admin/users/{username}/role`

---

## ?? Phase 2 Activation Status

### In AuthServer
- ? Dispatcher role activated
- ? Authorization policies implemented
- ? Role assignment endpoint created
- ? Admin endpoints protected

### In Other Components
- ? AdminAPI: Policies and field masking pending
- ? Admin Portal: Role-based UI pending
- ? Driver App: No changes needed
- ? Passenger App: No changes needed

---

## ?? Full Documentation

### Phase 1
- **Implementation:** `Docs/AuthServer-Phase1.md`
- **Testing:** See testing section in Phase 1 doc
- **Platform:** `Docs/Platform-Phase1.md`

### Phase 2
- **Implementation:** `Docs/AuthServer-Phase2.md`
- **Integration:** `Docs/AdminAPI-Phase2-Reference.md`
- **Platform:** `Docs/Platform-Phase2.md` (to be created)

---

**Quick Answer for Phase 1:** Use `userId` claim for all audit tracking. It's always an Identity GUID.

**Quick Answer for Phase 2:** Use `StaffOnly` policy for endpoints that both admins and dispatchers need. Use `AdminOnly` for sensitive operations.
