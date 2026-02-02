# Alpha: Admin User Provisioning

## Overview
Admin-only endpoints for creating users and managing roles using ASP.NET Identity. These endpoints are intended for AdminApi/Portal staff provisioning.

> Note: The current Identity user model does not store `firstName` or `lastName`. Those fields are accepted in requests for future expansion but are not persisted or returned.

## Endpoints

### GET /admin/users?take=50&skip=0
List users with their roles.

**Response**: Array of `UserSummaryDto`.

### POST /admin/users
Create a user with a temporary password and optional roles.

**Body**: `CreateUserRequest`
```json
{
  "email": "new.user@example.com",
  "firstName": "New",
  "lastName": "User",
  "tempPassword": "TempPass123",
  "roles": ["dispatcher"]
}
```

**Response**: `UserSummaryDto` (password is never returned).

### PUT /admin/users/{userId}/roles
Replace the roles for a user.

**Body**: `UpdateRolesRequest`
```json
{
  "roles": ["booker"]
}
```

**Response**: `UserSummaryDto`.

### PUT /admin/users/{userId}/disable
Disable a user account (lockout).

**Response**: `UserSummaryDto`.

## Manual Test Steps

1. Obtain an admin token via `/login` with an admin user.
2. Create a user:
   ```bash
   curl -X POST http://localhost:5000/admin/users \
     -H "Authorization: Bearer <token>" \
     -H "Content-Type: application/json" \
     -d '{"email":"new.user@example.com","tempPassword":"TempPass123","roles":["dispatcher"]}'
   ```
3. List users:
   ```bash
   curl -X GET "http://localhost:5000/admin/users?take=10&skip=0" \
     -H "Authorization: Bearer <token>"
   ```
4. Replace roles:
   ```bash
   curl -X PUT http://localhost:5000/admin/users/<userId>/roles \
     -H "Authorization: Bearer <token>" \
     -H "Content-Type: application/json" \
     -d '{"roles":["booker"]}'
   ```
5. Disable user:
   ```bash
   curl -X PUT http://localhost:5000/admin/users/<userId>/disable \
     -H "Authorization: Bearer <token>"
   ```
