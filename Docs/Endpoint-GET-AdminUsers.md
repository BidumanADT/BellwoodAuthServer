# GET /api/admin/users - Endpoint Documentation

**Component:** AuthServer  
**Phase:** Phase 2 - Admin Portal Integration  
**Date Added:** January 18, 2026  
**Status:** ? **IMPLEMENTED & READY**

---

## ?? Overview

**Purpose:** Retrieve a list of all users for the admin management interface in the Admin Portal.

**Authorization:** Admin-only (AdminOnly policy)

**HTTP Method:** GET

**Endpoint:** `/api/admin/users`

**Controller:** `AdminUsersController`

---

## ?? Authorization

**Policy:** `AdminOnly`

**Required Role:** `admin`

**Access Control:**
- ? **Admin users:** Full access
- ? **Dispatcher users:** 403 Forbidden
- ? **Booker users:** 403 Forbidden
- ? **Driver users:** 403 Forbidden
- ? **Unauthenticated:** 401 Unauthorized

---

## ?? Request

### **Headers**

```http
GET /api/admin/users HTTP/1.1
Host: localhost:5001
Authorization: Bearer {admin_jwt_token}
```

### **Query Parameters (All Optional)**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `role` | string | *(none)* | Filter by role: admin, dispatcher, booker, driver |
| `includeInactive` | boolean | false | Include inactive/disabled users |

### **Request Examples**

**Get all active users:**
```http
GET /api/admin/users HTTP/1.1
Authorization: Bearer eyJ...
```

**Get only admin users:**
```http
GET /api/admin/users?role=admin HTTP/1.1
Authorization: Bearer eyJ...
```

**Get dispatchers:**
```http
GET /api/admin/users?role=dispatcher HTTP/1.1
Authorization: Bearer eyJ...
```

**Get all users including inactive:**
```http
GET /api/admin/users?includeInactive=true HTTP/1.1
Authorization: Bearer eyJ...
```

---

## ?? Response

### **Success Response (200 OK)**

```json
[
  {
    "username": "alice",
    "userId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "email": "alice.admin@bellwood.example",
    "role": "admin",
    "isActive": true,
    "createdAt": "2026-01-18T00:00:00Z",
    "lastLogin": null
  },
  {
    "username": "bob",
    "userId": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
    "email": "bob.admin@bellwood.example",
    "role": "admin",
    "isActive": true,
    "createdAt": "2026-01-18T00:00:00Z",
    "lastLogin": null
  },
  {
    "username": "chris",
    "userId": "c3d4e5f6-a7b8-9012-cdef-123456789012",
    "email": "chris.bailey@example.com",
    "role": "booker",
    "isActive": true,
    "createdAt": "2026-01-18T00:00:00Z",
    "lastLogin": null
  },
  {
    "username": "charlie",
    "userId": "d4e5f6a7-b8c9-0123-def1-234567890123",
    "email": "",
    "role": "driver",
    "isActive": true,
    "createdAt": "2026-01-18T00:00:00Z",
    "lastLogin": null
  },
  {
    "username": "diana",
    "userId": "e5f6a7b8-c9d0-1234-ef12-345678901234",
    "email": "diana.dispatcher@bellwood.example",
    "role": "dispatcher",
    "isActive": true,
    "createdAt": "2026-01-18T00:00:00Z",
    "lastLogin": null
  }
]
```

### **Response Fields**

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `username` | string | Login username | "alice" |
| `userId` | string | Unique user ID (GUID) | "a1b2c3d4-..." |
| `email` | string | User's email address | "alice.admin@bellwood.example" |
| `role` | string | User's primary role | "admin" |
| `isActive` | boolean | Whether account is active | true |
| `createdAt` | datetime | Account creation timestamp* | "2026-01-18T00:00:00Z" |
| `lastLogin` | datetime? | Last login timestamp** | null |

**Notes:**
- *`createdAt`: Currently returns a placeholder value as ASP.NET Identity doesn't track creation dates by default.
- **`lastLogin`: Currently returns `null` as login tracking is not yet implemented. Requires login tracking middleware for accurate values.

---

### **Error Responses**

**401 Unauthorized (No Token)**
```json
{
  "type": "https://tools.ietf.org/html/rfc7235#section-3.1",
  "title": "Unauthorized",
  "status": 401
}
```

**403 Forbidden (Not Admin)**
```json
{
  "type": "https://tools.ietf.org/html/rfc7231#section-6.5.3",
  "title": "Forbidden",
  "status": 403
}
```

---

## ?? Usage Examples

### **C# / Blazor**

```csharp
public class UserManagementService
{
    private readonly HttpClient _httpClient;

    public async Task<List<UserInfo>> GetAllUsersAsync()
    {
        var response = await _httpClient.GetAsync("/api/admin/users");
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadFromJsonAsync<List<UserInfo>>();
    }

    public async Task<List<UserInfo>> GetUsersByRoleAsync(string role)
    {
        var response = await _httpClient.GetAsync($"/api/admin/users?role={role}");
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadFromJsonAsync<List<UserInfo>>();
    }
}

public class UserInfo
{
    public string Username { get; set; }
    public string UserId { get; set; }
    public string Email { get; set; }
    public string Role { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? LastLogin { get; set; }
}
```

### **JavaScript / TypeScript**

```typescript
interface UserInfo {
  username: string;
  userId: string;
  email: string;
  role: string;
  isActive: boolean;
  createdAt: string;
  lastLogin: string | null;
}

async function getAllUsers(token: string): Promise<UserInfo[]> {
  const response = await fetch('https://localhost:5001/api/admin/users', {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
  
  if (!response.ok) {
    throw new Error(`Failed to get users: ${response.status}`);
  }
  
  return await response.json();
}

async function getUsersByRole(token: string, role: string): Promise<UserInfo[]> {
  const response = await fetch(
    `https://localhost:5001/api/admin/users?role=${role}`,
    {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    }
  );
  
  return await response.json();
}
```

### **PowerShell**

```powershell
# Get all users
$headers = @{
    Authorization = "Bearer $adminToken"
}

$users = Invoke-RestMethod `
    -Uri "https://localhost:5001/api/admin/users" `
    -Method Get `
    -Headers $headers

# Get only dispatchers
$dispatchers = Invoke-RestMethod `
    -Uri "https://localhost:5001/api/admin/users?role=dispatcher" `
    -Method Get `
    -Headers $headers
```

### **cURL**

```bash
# Get all users
curl -X GET "https://localhost:5001/api/admin/users" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# Get admins only
curl -X GET "https://localhost:5001/api/admin/users?role=admin" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# Get all including inactive
curl -X GET "https://localhost:5001/api/admin/users?includeInactive=true" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

---

## ?? Behavior Details

### **Role Filtering**

The `role` query parameter filters users by their primary role. Due to the mutually exclusive role strategy in Phase 2, each user has exactly one role.

**Filter Values:**
- `admin` - System administrators
- `dispatcher` - Operational staff
- `booker` - Passengers/concierges
- `driver` - Professional drivers

**Case Insensitive:** Role filtering is case-insensitive (`?role=Admin` works the same as `?role=admin`)

### **Inactive User Handling**

**Default Behavior (includeInactive=false):**
- Only returns active users
- Users locked out (LockoutEnd > now) are excluded

**With includeInactive=true:**
- Returns all users regardless of lockout status
- Use for administrative purposes (viewing disabled accounts)

**Active Status Determination:**
```csharp
isActive = !user.LockoutEnabled || 
           !user.LockoutEnd.HasValue || 
           user.LockoutEnd.Value <= DateTimeOffset.UtcNow
```

### **Result Ordering**

Users are returned sorted alphabetically by username for consistent ordering.

---

## ?? Known Limitations

### **1. CreatedAt Field**

**Current Behavior:** Returns placeholder value (current date/time)

**Reason:** ASP.NET Core Identity doesn't track user creation dates by default

**Future Enhancement:** Extend IdentityUser with CreatedAt column or maintain separate user metadata table

### **2. LastLogin Field**

**Current Behavior:** Always returns `null`

**Reason:** Login tracking not implemented

**Future Enhancement:** Implement login tracking middleware:
```csharp
app.Use(async (context, next) =>
{
    await next();
    if (context.User?.Identity?.IsAuthenticated == true)
    {
        // Update last login timestamp
        await trackingService.UpdateLastLoginAsync(context.User.Identity.Name);
    }
});
```

---

## ?? Testing

### **Manual Testing**

**Prerequisites:**
1. AuthServer running on https://localhost:5001
2. Admin user credentials (alice/password or bob/password)

**Test Steps:**

1. **Login as admin:**
   ```bash
   curl -X POST https://localhost:5001/login \
     -H "Content-Type: application/json" \
     -d '{"username":"alice","password":"password"}'
   ```

2. **Get all users:**
   ```bash
   curl -X GET https://localhost:5001/api/admin/users \
     -H "Authorization: Bearer $TOKEN"
   ```

3. **Verify response contains expected users:**
   - alice (admin)
   - bob (admin)
   - chris (booker)
   - charlie (driver)
   - diana (dispatcher)

4. **Test role filtering:**
   ```bash
   curl -X GET "https://localhost:5001/api/admin/users?role=dispatcher" \
     -H "Authorization: Bearer $TOKEN"
   ```
   Expected: Only diana

5. **Test authorization (as dispatcher):**
   ```bash
   # Login as diana
   curl -X POST https://localhost:5001/login \
     -H "Content-Type: application/json" \
     -d '{"username":"diana","password":"password"}'
   
   # Try to access endpoint (should fail)
   curl -X GET https://localhost:5001/api/admin/users \
     -H "Authorization: Bearer $DIANA_TOKEN"
   ```
   Expected: 403 Forbidden

### **Automated Testing**

**Test Script:** `Scripts/test-get-users-endpoint.ps1`

**Run:**
```powershell
.\Scripts\test-get-users-endpoint.ps1
```

**Tests Performed:**
1. ? Get all users (no filter)
2. ? Filter by role: admin
3. ? Filter by role: dispatcher
4. ? Filter by role: driver
5. ? Authorization (dispatcher denied)
6. ? Response format validation

---

## ?? Performance Considerations

**Current Implementation:**
- Loads all users into memory
- Fetches roles and claims for each user (N+1 queries)
- Suitable for small to medium user bases (< 10,000 users)

**For Large User Bases:**
Consider implementing:
1. **Pagination:**
   ```
   ?page=1&pageSize=50
   ```

2. **Eager Loading:**
   ```csharp
   var users = _userManager.Users
       .Include(u => u.Roles)
       .ToListAsync();
   ```

3. **Projection:**
   Return only necessary fields to reduce payload size

---

## ?? Related Endpoints

**User Management:**
- `GET /api/admin/users` - List all users (this endpoint)
- `PUT /api/admin/users/{username}/role` - Change user role
- `GET /api/admin/users/drivers` - List driver users only
- `DELETE /api/admin/users/drivers/{username}` - Delete driver user

**Diagnostics:**
- `GET /dev/user-info/{username}` - Get detailed user info (dev only)

---

## ?? Change Log

### Version 1.0 - January 18, 2026
- Initial implementation
- Support for role filtering
- Support for inactive user inclusion
- AdminOnly authorization applied
- Email addresses added to alice and bob seed data

---

## ?? Admin Portal Integration

**For Admin Portal Developers:**

1. **Call endpoint on user management page load**
2. **Display users in table/grid**
3. **Implement role filter dropdown**
4. **Show/hide based on admin user's role**
5. **Link to user detail/edit pages**

**Example Blazor Component:**

```razor
@page "/admin/users"
@attribute [Authorize(Policy = "AdminOnly")]
@inject HttpClient Http

<h3>User Management</h3>

<select @bind="selectedRole" @bind:after="LoadUsers">
    <option value="">All Roles</option>
    <option value="admin">Admins</option>
    <option value="dispatcher">Dispatchers</option>
    <option value="booker">Bookers</option>
    <option value="driver">Drivers</option>
</select>

<table class="table">
    <thead>
        <tr>
            <th>Username</th>
            <th>Email</th>
            <th>Role</th>
            <th>Status</th>
            <th>Actions</th>
        </tr>
    </thead>
    <tbody>
        @foreach (var user in users)
        {
            <tr>
                <td>@user.Username</td>
                <td>@user.Email</td>
                <td>@user.Role</td>
                <td>
                    @if (user.IsActive)
                    {
                        <span class="badge bg-success">Active</span>
                    }
                    else
                    {
                        <span class="badge bg-danger">Inactive</span>
                    }
                </td>
                <td>
                    <button @onclick="() => EditUser(user.Username)">Edit</button>
                </td>
            </tr>
        }
    </tbody>
</table>

@code {
    private List<UserInfo> users = new();
    private string selectedRole = "";

    protected override async Task OnInitializedAsync()
    {
        await LoadUsers();
    }

    private async Task LoadUsers()
    {
        var url = string.IsNullOrEmpty(selectedRole) 
            ? "/api/admin/users" 
            : $"/api/admin/users?role={selectedRole}";
            
        users = await Http.GetFromJsonAsync<List<UserInfo>>(url) ?? new();
    }

    private void EditUser(string username)
    {
        // Navigate to edit page
    }
}
```

---

**Status:** ? **READY FOR INTEGRATION**  
**Tested:** Manual testing pending (server restart required)  
**Documentation:** Complete  
**Last Updated:** January 18, 2026

---

*This endpoint provides the foundation for user management UI in the Admin Portal. The response format matches Portal team specifications with minor enhancements (isActive, role) for better UX.* ???
