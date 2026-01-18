# AuthServer - Phase 2: Role-Based Access Control

**Component:** AuthServer  
**Phase:** Phase 2 - RBAC & Dispatcher Role  
**Status:** ? **COMPLETE**  
**Date:** January 13, 2026  
**Version:** 1.0

---

## ?? Table of Contents

- [Overview](#overview)
- [Changes Implemented](#changes-implemented)
- [Dispatcher Role](#dispatcher-role)
- [Authorization Policies](#authorization-policies)
- [Role Assignment](#role-assignment)
- [Testing Guide](#testing-guide)
- [Integration Notes](#integration-notes)

---

## Overview

### Objective
Introduce the dispatcher role and enforce role-based access control (RBAC) across AuthServer endpoints to support least-privilege access principles.

### Scope
- Activate dispatcher role
- Implement authorization policies (AdminOnly, StaffOnly)
- Create role assignment endpoint
- Protect admin endpoints with policies

### Success Criteria
- [x] Dispatcher role activated and seeded
- [x] Test user "diana" created with dispatcher role
- [x] Authorization policies implemented
- [x] Role assignment endpoint created
- [x] Admin endpoints protected
- [x] Build successful
- [x] Documentation complete

---

## Changes Implemented

### 1. Dispatcher Role Activation

**File Modified:** `Program.cs`

**Change:** Activated Phase 2 role seeding by uncommenting the call to `Phase2RolePreparation.SeedDispatcherRole()`.

**Implementation:**
```csharp
// PHASE 2: Seed dispatcher role and test user
await Phase2RolePreparation.SeedDispatcherRole(rm, um);
```

**Result:**
- Dispatcher role created in database
- Test user "diana" created with dispatcher role
- Email claim configured for diana

**Test User Details:**
- Username: `diana`
- Password: `password`
- Role: `dispatcher`
- Email: `diana.dispatcher@bellwood.example`

---

### 2. Authorization Policies

**File Modified:** `Program.cs`

**Policies Created:**

#### **AdminOnly**
- **Requires:** `admin` role
- **Use For:** Sensitive operations (user management, role assignment)
- **Implementation:**
  ```csharp
  options.AddPolicy("AdminOnly", policy =>
      policy.RequireRole("admin"));
  ```

#### **StaffOnly**
- **Requires:** `admin` OR `dispatcher` role
- **Use For:** Operational endpoints accessible to staff
- **Implementation:**
  ```csharp
  options.AddPolicy("StaffOnly", policy =>
      policy.RequireRole("admin", "dispatcher"));
  ```

#### **DriverOnly**
- **Requires:** `driver` role
- **Use For:** Driver-specific endpoints
- **Note:** Already used in AdminAPI, included here for consistency

#### **BookerOnly**
- **Requires:** `booker` role
- **Use For:** Passenger-specific endpoints
- **Note:** For future use if needed

---

### 3. Role Assignment Endpoint

**New Endpoint:** `PUT /api/admin/users/{username}/role`

**Purpose:** Allows admins to assign roles to users (mutually exclusive strategy).

**Authorization:** Requires `AdminOnly` policy

**Request:**
```http
PUT /api/admin/users/bob/role
Authorization: Bearer <admin-jwt>
Content-Type: application/json

{
  "role": "dispatcher"
}
```

**Response (Success):**
```json
{
  "message": "Successfully assigned role 'dispatcher' to user 'bob'.",
  "username": "bob",
  "previousRoles": ["admin"],
  "newRole": "dispatcher"
}
```

**Features:**
- Validates role is one of: `admin`, `dispatcher`, `booker`, `driver`
- Removes existing roles before assigning new one (mutually exclusive)
- Returns detailed response with previous and new roles
- Only admins can call this endpoint

**Error Responses:**

**400 Bad Request - Invalid Role:**
```json
{
  "error": "Invalid role 'invalid'. Valid roles are: admin, dispatcher, booker, driver"
}
```

**404 Not Found - User Not Found:**
```json
{
  "error": "User 'unknown' not found."
}
```

**Already Has Role:**
```json
{
  "message": "User 'bob' already has role 'dispatcher'.",
  "username": "bob",
  "role": "dispatcher",
  "previousRoles": ["dispatcher"]
}
```

---

### 4. Protected Admin Endpoints

**File Modified:** `Controllers/AdminUsersController.cs`

**Change:** Applied `[Authorize(Policy = "AdminOnly")]` at controller level.

**Protected Endpoints:**
- `POST /api/admin/users/drivers` - Create driver user
- `PUT /api/admin/users/{username}/uid` - Update user UID
- `GET /api/admin/users/drivers` - List driver users
- `GET /api/admin/users/by-uid/{userUid}` - Get user by UID
- `DELETE /api/admin/users/drivers/{username}` - Delete driver user
- `GET /api/admin/users` - **List all users** ? **NEW (Portal Integration)**

**Result:**
- All endpoints now require admin role
- Dispatchers cannot create/modify users
- Clear separation of admin vs operational duties

---

### 5. User Data Enhancements

**File Modified:** `Program.cs`

**Change:** Added email addresses to admin test users.

**Updated Users:**
- alice: Added `alice.admin@bellwood.example`
- bob: Added `bob.admin@bellwood.example`

**Result:**
- Better user management display in Admin Portal
- Consistent email configuration across all test users
- Email claims automatically generated

---

## Dispatcher Role

### What is a Dispatcher?

**Purpose:** Staff member responsible for operational tasks (assigning drivers, managing bookings) without access to sensitive administrative functions.

**Capabilities (in AdminAPI Phase 2):**
- ? View all bookings and quotes
- ? Assign drivers to bookings
- ? Approve quotes
- ? Manage operational data
- ? View billing information
- ? Manage users or roles
- ? Access financial reports

**In AuthServer:**
- Dispatcher role exists and can be assigned
- Dispatchers cannot access admin endpoints
- Dispatchers can access StaffOnly endpoints

---

### Dispatcher vs Admin

| Feature | Admin | Dispatcher |
|---------|-------|-----------|
| View all bookings | ? Yes | ? Yes |
| Assign drivers | ? Yes | ? Yes |
| View billing data | ? Yes | ? No (masked in AdminAPI) |
| Manage users | ? Yes | ? No |
| Assign roles | ? Yes | ? No |
| Access admin endpoints | ? Yes | ? No |
| Financial reports | ? Yes | ? No |

---

### Test User: Diana

**Credentials:**
- Username: `diana`
- Password: `password`

**JWT Claims (after login):**
```json
{
  "sub": "diana",
  "uid": "guid-xxx...",
  "userId": "guid-xxx...",
  "role": "dispatcher",
  "email": "diana.dispatcher@bellwood.example",
  "exp": 1704996000
}
```

**Testing:**
```bash
# Login as dispatcher
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"diana","password":"password"}'

# Try to access admin endpoint (should fail)
curl -X GET https://localhost:5001/api/admin/users/drivers \
  -H "Authorization: Bearer <diana-jwt>"
# Expected: 403 Forbidden
```

---

## Authorization Policies

### Policy Usage Patterns

#### AdminOnly Endpoints

**When to Use:**
- User management
- Role assignment
- Sensitive configuration
- Financial operations

**Example:**
```csharp
[Authorize(Policy = "AdminOnly")]
public class SensitiveController : ControllerBase
{
    // Only admins can access
}
```

**Minimal API:**
```csharp
app.MapPost("/api/admin/something", async () =>
{
    // Admin-only logic
})
.RequireAuthorization("AdminOnly");
```

---

#### StaffOnly Endpoints

**When to Use:**
- Operational tasks
- Data access for both admins and dispatchers
- General staff functions

**Example:**
```csharp
[Authorize(Policy = "StaffOnly")]
public async Task<IActionResult> AssignDriver(/* params */)
{
    // Both admin and dispatcher can call
}
```

**AdminAPI Integration:**
- Most booking/quote management endpoints should use StaffOnly
- Allows dispatchers to do their job
- Admins retain full access

---

#### Role-Specific Policies

**DriverOnly:**
```csharp
[Authorize(Policy = "DriverOnly")]
public async Task<IActionResult> GetMyRides()
{
    // Only drivers can access
}
```

**BookerOnly:**
```csharp
[Authorize(Policy = "BookerOnly")]
public async Task<IActionResult> GetMyBookings()
{
    // Only passengers/concierges can access
}
```

---

### Policy Enforcement Flow

```
Request ? JWT Validation ? Extract Role Claim ? Check Policy ? Allow/Deny

Example:
1. User sends request with JWT
2. Middleware validates JWT signature
3. Extracts "role" claim from token
4. Checks if role matches policy requirement
5. If match: Allow request
6. If no match: Return 403 Forbidden
```

---

## Role Assignment

### Mutually Exclusive Strategy

**Phase 2 Decision:** Users have ONE role at a time.

**Rationale:**
- Simpler authorization logic
- Clear audit trail
- Easy to understand permissions
- Prevents ambiguity

**Implementation:**
- When assigning new role, remove existing role first
- User can only be admin OR dispatcher (not both)
- Similarly: booker OR driver

**Future:** If multi-role support needed, infrastructure already exists (JWT supports multiple role claims).

---

### How to Change a User's Role

**Promote Admin to Dispatcher:**
```bash
curl -X PUT https://localhost:5001/api/admin/users/bob/role \
  -H "Authorization: Bearer <admin-jwt>" \
  -H "Content-Type: application/json" \
  -d '{"role":"dispatcher"}'
```

**Demote Dispatcher to Admin:**
```bash
curl -X PUT https://localhost:5001/api/admin/users/bob/role \
  -H "Authorization: Bearer <admin-jwt>" \
  -H "Content-Type: application/json" \
  -d '{"role":"admin"}'
```

**Result:**
- Previous role removed
- New role assigned
- Next JWT will contain new role
- User must re-login to get updated token

---

### Valid Roles

| Role | Purpose | Typical Users |
|------|---------|---------------|
| `admin` | Full system access | System administrators |
| `dispatcher` | Operational staff | Dispatch coordinators |
| `booker` | Create bookings | Passengers, concierges |
| `driver` | Drive assignments | Professional drivers |

---

## Testing Guide

### Test 1: Dispatcher Role Seeding

**Objective:** Verify dispatcher role and test user created.

**Steps:**
1. Start AuthServer
2. Check logs for "Phase 2" seeding
3. Login as diana

**Request:**
```bash
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"diana","password":"password"}'
```

**Expected JWT Claims:**
```json
{
  "sub": "diana",
  "role": "dispatcher",
  "email": "diana.dispatcher@bellwood.example"
}
```

**? Pass Criteria:**
- Login successful
- Token contains `dispatcher` role
- Email claim present

---

### Test 2: AdminOnly Policy Enforcement

**Objective:** Verify dispatchers cannot access admin endpoints.

**Steps:**
1. Login as dispatcher (diana)
2. Attempt to access admin endpoint

**Request:**
```bash
# Login as diana
DIANA_TOKEN=$(curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"diana","password":"password"}' | jq -r '.token')

# Try to access admin endpoint
curl -X GET https://localhost:5001/api/admin/users/drivers \
  -H "Authorization: Bearer $DIANA_TOKEN"
```

**Expected Response:**
```
403 Forbidden
```

**? Pass Criteria:**
- Dispatcher denied access
- Returns 403 status code

---

### Test 3: Admin Can Access Protected Endpoints

**Objective:** Verify admins retain full access.

**Steps:**
1. Login as admin (alice)
2. Access admin endpoint

**Request:**
```bash
# Login as alice
ALICE_TOKEN=$(curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"password"}' | jq -r '.token')

# Access admin endpoint
curl -X GET https://localhost:5001/api/admin/users/drivers \
  -H "Authorization: Bearer $ALICE_TOKEN"
```

**Expected Response:**
```json
[
  {
    "userId": "...",
    "username": "charlie",
    "userUid": "driver-001"
  }
]
```

**? Pass Criteria:**
- Admin granted access
- Returns 200 OK with data

---

### Test 4: Role Assignment

**Objective:** Verify role assignment endpoint works.

**Scenario 1: Promote Admin to Dispatcher**

**Request:**
```bash
curl -X PUT https://localhost:5001/api/admin/users/bob/role \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"role":"dispatcher"}'
```

**Expected Response:**
```json
{
  "message": "Successfully assigned role 'dispatcher' to user 'bob'.",
  "username": "bob",
  "previousRoles": ["admin"],
  "newRole": "dispatcher"
}
```

**? Pass Criteria:**
- Role changed successfully
- Previous role removed
- Response shows both old and new roles

---

**Scenario 2: Verify Bob Now Has Dispatcher Role**

**Request:**
```bash
# Bob logs in
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"bob","password":"password"}'
```

**Expected JWT:**
```json
{
  "role": "dispatcher"  // Changed from admin
}
```

**? Pass Criteria:**
- Bob's token has dispatcher role
- No admin role present

---

**Scenario 3: Bob Cannot Access Admin Endpoints**

**Request:**
```bash
BOB_TOKEN=$(curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"bob","password":"password"}' | jq -r '.token')

curl -X GET https://localhost:5001/api/admin/users/drivers \
  -H "Authorization: Bearer $BOB_TOKEN"
```

**Expected Response:**
```
403 Forbidden
```

**? Pass Criteria:**
- Bob denied access to admin endpoints
- Returns 403 status

---

### Test 5: Invalid Role Assignment

**Objective:** Verify validation works.

**Request:**
```bash
curl -X PUT https://localhost:5001/api/admin/users/bob/role \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"role":"invalid"}'
```

**Expected Response:**
```json
{
  "error": "Invalid role 'invalid'. Valid roles are: admin, dispatcher, booker, driver"
}
```

**? Pass Criteria:**
- Request rejected
- Helpful error message
- Returns 400 Bad Request

---

### Test 6: Non-Admin Cannot Assign Roles

**Objective:** Verify only admins can assign roles.

**Request:**
```bash
# Diana (dispatcher) tries to promote someone
curl -X PUT https://localhost:5001/api/admin/users/charlie/role \
  -H "Authorization: Bearer $DIANA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"role":"admin"}'
```

**Expected Response:**
```
403 Forbidden
```

**? Pass Criteria:**
- Dispatcher cannot assign roles
- Returns 403 status

---

## Integration Notes

### For AdminAPI Team

**Phase 2 Requirements:**

1. **Implement StaffOnly Policy:**
   ```csharp
   options.AddPolicy("StaffOnly", policy =>
       policy.RequireRole("admin", "dispatcher"));
   ```

2. **Apply to Operational Endpoints:**
   - Booking list/detail
   - Quote list/detail
   - Driver assignment
   - Quote approval

3. **Field Masking for Dispatchers:**
   ```csharp
   if (User.IsInRole("dispatcher"))
   {
       // Mask sensitive fields
       booking.PaymentMethodId = null;
       booking.BillingAmount = null;
       // etc.
   }
   ```

4. **Keep AdminOnly for Sensitive Endpoints:**
   - Financial reports
   - Billing endpoints
   - User management (if implemented)

---

### For Admin Portal Team

**Phase 2 Changes:**

1. **Role-Based UI Hiding:**
   ```razor
   @if (User.IsInRole("admin"))
   {
       <NavLink href="/billing">Billing</NavLink>
   }
   ```

2. **Dispatcher Dashboard:**
   - Show operational tabs only
   - Hide billing, user management
   - Clear indication of role

3. **Role Assignment UI:**
   - Admin can change user roles
   - Calls `PUT /api/admin/users/{username}/role`
   - Shows current role and allows selection

---

### JWT Structure (Phase 2)

**Admin User:**
```json
{
  "sub": "alice",
  "uid": "guid-xxx...",
  "userId": "guid-xxx...",
  "role": "admin"
}
```

**Dispatcher User:**
```json
{
  "sub": "diana",
  "uid": "guid-xxx...",
  "userId": "guid-xxx...",
  "role": "dispatcher",
  "email": "diana.dispatcher@bellwood.example"
}
```

**No Changes to:**
- Booker JWTs
- Driver JWTs
- Token expiration
- Refresh token flow

---

## Security Enhancements

### What Phase 2 Adds

**Before Phase 2:**
- ? No dispatcher role
- ? Admin endpoints open to all authenticated users
- ? No way to assign roles programmatically

**After Phase 2:**
- ? Dispatcher role exists
- ? Admin endpoints protected with AdminOnly policy
- ? Role assignment endpoint available
- ? Clear separation of admin vs operational duties

---

### Remaining Security Considerations

**For Future Phases:**

1. **Password Strength:**
   - Current: 6 characters, no complexity required
   - Recommended: Enforce stronger policies for admin/dispatcher

2. **MFA for Admins:**
   - Add two-factor authentication for admin accounts
   - Protects sensitive operations

3. **Audit Logging:**
   - Log role assignment changes
   - Track admin endpoint access
   - Monitor failed authorization attempts

4. **Token Refresh Security:**
   - Move from in-memory to persistent storage
   - Add refresh token rotation

---

## Known Limitations

**Phase 2 Scope:**
- OAuth credential management NOT in AuthServer (moved to AdminAPI)
- Field masking implemented in AdminAPI (not AuthServer responsibility)
- No UI for role management yet (Admin Portal Phase 2)
- Single role per user (can be extended if needed)

---

## Related Documentation

**AuthServer:**
- `Docs/AuthServer-Phase1.md` - Phase 1 implementation

**Platform-Wide:**
- `Docs/Platform-Phase2.md` - All components Phase 2 overview (to be created)
- `Docs/Planning-DataAccess.md` - Overall strategy

**AdminAPI:**
- AdminAPI Phase 2 implementation (separate component)

**Admin Portal:**
- Portal Phase 2 implementation (separate component)

---

## Change Log

### Version 1.0 - January 13, 2026
- Activated dispatcher role
- Implemented authorization policies
- Created role assignment endpoint
- Protected admin endpoints
- Comprehensive testing guide

---

**Status:** ? **COMPLETE AND PRODUCTION-READY**  
**Version:** 1.0  
**Last Updated:** January 13, 2026  
**Maintained By:** AuthServer Team

---

*AuthServer Phase 2 establishes role-based access control foundation for the platform. AdminAPI and Admin Portal Phase 2 will build upon these capabilities.* ???
