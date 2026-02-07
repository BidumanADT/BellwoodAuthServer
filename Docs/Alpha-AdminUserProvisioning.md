# Admin User Provisioning API

## Overview
Admin-only endpoints for creating users and managing roles using ASP.NET Identity. These endpoints are intended for AdminAPI/Portal staff provisioning.

> **Note:** The current Identity user model does not store `firstName` or `lastName`. Those fields are accepted in requests for future expansion but are not persisted or returned.

## Canonical Routes

All admin user provisioning endpoints are now standardized under `/api/admin/users`:

- ? **Primary Route:** `/api/admin/users` (use this)
- ?? **Legacy Route:** `/api/admin/provisioning` (deprecated, maintained for backward compatibility)

---

## Endpoints

### GET /api/admin/users?take=50&skip=0
List users with their roles and status.

**Query Parameters:**
- `take` (optional): Number of users to return (default: 50)
- `skip` (optional): Number of users to skip for pagination (default: 0)

**Response:** Array of `UserSummaryDto`
```json
[
  {
    "userId": "guid",
    "email": "user@example.com",
    "firstName": null,
    "lastName": null,
    "roles": ["dispatcher"],
    "isDisabled": false,
    "createdAtUtc": null,
    "modifiedAtUtc": null
  }
]
```

---

### POST /api/admin/users
Create a user with a temporary password and optional roles.

**Body:** `CreateUserRequest`
```json
{
  "email": "new.user@example.com",
  "firstName": "New",
  "lastName": "User",
  "tempPassword": "TempPass123!",
  "roles": ["dispatcher"]
}
```

**Success Response (200):** `UserSummaryDto` (password is **never** returned)

**Error Responses:**
- `400 Bad Request` - Missing email/password or invalid roles
- `409 Conflict` - Email already exists

**Notes:**
- Email is auto-confirmed for admin-created users
- Roles are normalized to lowercase
- Valid roles: `admin`, `dispatcher`, `booker`, `driver`

---

### PUT /api/admin/users/{userId}/roles
Replace all roles for a user (mutually exclusive).

**Body:** `UpdateRolesRequest`
```json
{
  "roles": ["booker"]
}
```

**Response:** `UserSummaryDto`

**Notes:**
- Removes all existing roles before adding new ones
- Roles are normalized to lowercase
- Empty array is valid (removes all roles)

---

### PUT /api/admin/users/{userId}/disable
Disable a user account (prevents login).

**Response:** `UserSummaryDto` with `isDisabled: true`

**Notes:**
- User cannot log in while disabled
- Login attempts return `403 Forbidden`
- Lockout is set to 100 years (effectively permanent)

---

### PUT /api/admin/users/{userId}/enable
Re-enable a disabled user account.

**Response:** `UserSummaryDto` with `isDisabled: false`

**Notes:**
- Removes lockout
- User can log in immediately after enable

---

## Legacy Endpoints (Deprecated)

The following endpoints are **deprecated** but maintained for backward compatibility:

### ?? PUT /api/admin/users/{username}/role
Single role assignment by username (use `/api/admin/users/{userId}/roles` instead).

**Body:**
```json
{
  "role": "dispatcher"
}
```

**Deprecation Notice:** This endpoint will be removed in a future version. Migrate to the standardized `/api/admin/users/{userId}/roles` endpoint.

---

## Role Normalization

All roles are automatically normalized to **lowercase** for consistency:
- Input: `["Admin", "DISPATCHER"]` ? Stored/Returned: `["admin", "dispatcher"]`
- Valid roles: `admin`, `dispatcher`, `booker`, `driver`

---

## Manual Test Checklist

### 1. Obtain Admin Token
```bash
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"password"}'
```

### 2. Create User
```bash
curl -X POST https://localhost:5001/api/admin/users \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test.user@example.com",
    "tempPassword": "TempPass123!",
    "roles": ["dispatcher"]
  }'
```

**Expected:** 200 OK with user details (no password in response)

### 3. List Users
```bash
curl -X GET "https://localhost:5001/api/admin/users?take=10&skip=0" \
  -H "Authorization: Bearer <token>"
```

**Expected:** Array of users with normalized roles

### 4. Update Roles
```bash
curl -X PUT https://localhost:5001/api/admin/users/<userId>/roles \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"roles": ["booker"]}'
```

**Expected:** User now has only `["booker"]` role

### 5. Disable User
```bash
curl -X PUT https://localhost:5001/api/admin/users/<userId>/disable \
  -H "Authorization: Bearer <token>"
```

**Expected:** `isDisabled: true`

### 6. Verify Login Blocked
```bash
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user@example.com","password":"TempPass123!"}'
```

**Expected:** 403 Forbidden (Account Disabled)

### 7. Enable User
```bash
curl -X PUT https://localhost:5001/api/admin/users/<userId>/enable \
  -H "Authorization: Bearer <token>"
```

**Expected:** `isDisabled: false`

### 8. Verify Login Works
```bash
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test.user@example.com","password":"TempPass123!"}'
```

**Expected:** 200 OK with JWT token

---

## Automated Tests

Run the full test suite:
```powershell
.\Scripts\Run-AllTests.ps1 -StartupDelay 5
```

Or run provisioning tests only:
```powershell
.\Scripts\test-provisioning-api.ps1
```

---

## Migration Guide

### For AdminAPI/AdminPortal

**Old:**
```typescript
POST /api/admin/provisioning
PUT /api/admin/provisioning/{userId}/roles
```

**New:**
```typescript
POST /api/admin/users
PUT /api/admin/users/{userId}/roles
```

**Backward Compatibility:** Both routes work, but update to `/api/admin/users` for consistency.

---

## Security Notes

- ? All endpoints require `AdminOnly` policy (admin role)
- ? Passwords are **never** returned in responses
- ? Passwords are **never** logged
- ? Roles are normalized to prevent case-sensitivity issues
- ? Email uniqueness is enforced (both username and email fields)
- ? Disabled users cannot obtain tokens (403 Forbidden)

---

**Last Updated:** February 6, 2026  
**API Version:** Standardized to `/api/admin/users`
