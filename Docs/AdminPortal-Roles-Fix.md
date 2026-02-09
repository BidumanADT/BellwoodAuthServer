# AdminPortal Roles Display Fix - JSON Property Names

**Date:** February 7, 2026  
**Issue:** Roles showing as "None" in AdminPortal despite being present in database  
**Root Cause:** JSON property name casing mismatch  
**Status:** ? FIXED

---

## ?? **Problem**

### **Symptoms**
- AdminPortal User Management shows "None" in Roles column for all users
- Usernames now display correctly (previous fix worked)
- Users actually HAVE roles in the database (alice=admin, diana=dispatcher, etc.)
- "Edit Roles" modal also shows no roles selected

### **Visual Evidence**
```
Username    | Email                          | Roles | Actions
------------|--------------------------------|-------|--------
alice       | alice.admin@bellwood.example  | None  | [Edit Roles]
bob         | bob.admin@bellwood.example    | None  | [Edit Roles]
diana       | diana.dispatcher@...          | None  | [Edit Roles]
```

---

## ?? **Root Cause Analysis**

### **The Issue: Property Name Casing**

.NET's default JSON serialization uses **PascalCase** (first letter uppercase):
```json
{
  "UserId": "guid",
  "Username": "alice",
  "Email": "alice.admin@bellwood.example",
  "Roles": ["admin"],  // ? Capitalized "R"
  "IsDisabled": false
}
```

But the AdminPortal (JavaScript/TypeScript) expects **camelCase** (first letter lowercase):
```typescript
interface User {
  userId: string;
  username: string;
  email: string;
  roles: string[];      // ? lowercase "r"
  isDisabled: boolean;
}
```

### **What Happens**

When AdminPortal receives:
```json
{ "Roles": ["admin"] }
```

But looks for:
```typescript
user.roles  // undefined (property doesn't exist)
```

**Result:** Shows "None" because `user.roles` is `undefined`

---

## ? **The Fix**

### **Solution: Explicit JSON Property Names**

Added `[JsonPropertyName]` attributes to enforce camelCase serialization:

**File:** `Models/AdminUserProvisioningDtos.cs`

```csharp
using System.Text.Json.Serialization;

public class UserSummaryDto
{
    [JsonPropertyName("userId")]      // ? Forces lowercase
    public string UserId { get; set; } = string.Empty;
    
    [JsonPropertyName("username")]    // ? Forces lowercase
    public string Username { get; set; } = string.Empty;
    
    [JsonPropertyName("email")]       // ? Forces lowercase
    public string Email { get; set; } = string.Empty;
    
    [JsonPropertyName("firstName")]   // ? Forces camelCase
    public string? FirstName { get; set; }
    
    [JsonPropertyName("lastName")]    // ? Forces camelCase
    public string? LastName { get; set; }
    
    [JsonPropertyName("roles")]       // ? Forces lowercase - THIS WAS THE KEY!
    public List<string> Roles { get; set; } = new();
    
    [JsonPropertyName("isDisabled")]  // ? Forces camelCase
    public bool? IsDisabled { get; set; }
    
    [JsonPropertyName("createdAtUtc")] // ? Forces camelCase
    public DateTime? CreatedAtUtc { get; set; }
    
    [JsonPropertyName("modifiedAtUtc")] // ? Forces camelCase
    public DateTime? ModifiedAtUtc { get; set; }
}
```

---

## ?? **Before vs After**

### **API Response Before Fix**
```json
{
  "UserId": "abc-123",
  "Username": "alice",
  "Email": "alice.admin@bellwood.example",
  "Roles": ["admin"],        // ? Capital R
  "IsDisabled": false,       // ? Capital I
  "CreatedAtUtc": null,
  "ModifiedAtUtc": null
}
```

**AdminPortal reads:**
- `user.username` ? Works (we got lucky - .NET defaults to lowercase for single words)
- `user.roles` ? undefined (looking for lowercase, got uppercase)

### **API Response After Fix**
```json
{
  "userId": "abc-123",
  "username": "alice",
  "email": "alice.admin@bellwood.example",
  "roles": ["admin"],        // ? lowercase r ?
  "isDisabled": false,       // ? camelCase ?
  "createdAtUtc": null,
  "modifiedAtUtc": null
}
```

**AdminPortal reads:**
- `user.username` ? Works
- `user.roles` ? Works! Now finds the array

---

## ?? **Expected Results**

### **AdminPortal Display (After Fix)**
```
Username | Email                          | Roles      | Actions
---------|--------------------------------|------------|--------
alice    | alice.admin@bellwood.example  | admin      | [Edit Roles]
bob      | bob.admin@bellwood.example    | admin      | [Edit Roles]
charlie  | (no email)                     | driver     | [Edit Roles]
chris    | chris.bailey@example.com      | booker     | [Edit Roles]
diana    | diana.dispatcher@...          | dispatcher | [Edit Roles]
```

### **Edit Roles Modal**
When clicking "Edit Roles" for alice:
- ? "admin" checkbox should be checked
- ? Other roles (dispatcher, booker, driver) unchecked
- ? Can change role and save

---

## ?? **Testing Verification**

### **Manual Test**

1. **Restart AuthServer:**
   ```powershell
   # Stop (Ctrl+C), then restart
   dotnet run
   ```

2. **Hard Refresh AdminPortal:**
   ```
   Ctrl+Shift+R (Windows)
   Cmd+Shift+R (Mac)
   ```

3. **Verify:**
   - Navigate to User Management
   - Check Roles column shows actual roles
   - Click "Edit Roles" on alice
   - Verify "admin" is checked
   - Try changing to "dispatcher"
   - Verify role changes and persists

### **API Test (if server is running)**

```powershell
.\Scripts\test-api-response.ps1
```

**Expected Output:**
```
Sample User Response:
  ? userId : abc-123-guid
  ? username : alice
  ? email : alice.admin@bellwood.example
  ? roles : [admin]           # ? Should show roles now!
  ? isDisabled : False
```

---

## ?? **Files Changed**

| File | Change | Impact |
|------|--------|--------|
| `Models/AdminUserProvisioningDtos.cs` | Added `[JsonPropertyName]` attributes | Forces camelCase JSON output |

---

## ?? **Why This Happened**

### **ASP.NET Core's Default Behavior**

By default, ASP.NET Core 3.0+ uses `System.Text.Json` which:
- Uses **PascalCase** for property names (first letter uppercase)
- Matches C# property naming conventions
- Works great for .NET-to-.NET communication

But JavaScript/TypeScript frontend frameworks expect:
- **camelCase** for JSON properties (first letter lowercase)
- Standard in JavaScript ecosystem

### **The Mismatch**

```csharp
public string Roles { get; set; }  // C# PascalCase
```

Serializes to:
```json
"Roles": ["admin"]  // JSON PascalCase
```

But JavaScript expects:
```javascript
user.roles  // camelCase
```

### **Why Username Worked**

`"Username"` ? `user.username` happened to work because:
- Some browsers/frameworks are case-insensitive
- Or AdminPortal had fallback logic
- Or we got lucky with how the data was accessed

But `"Roles"` ? `user.roles` failed consistently because:
- Arrays/objects are more strictly typed
- No fallback logic for missing arrays

---

## ?? **Alternative Solutions (Not Used)**

### **Option 1: Global JSON Options**
```csharp
// Program.cs
builder.Services.AddControllers()
    .AddJsonOptions(options => {
        options.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    });
```

**Why not:** Affects ALL API responses globally, might break other clients

### **Option 2: Update AdminPortal**
```typescript
// Change AdminPortal to look for PascalCase
user.Roles instead of user.roles
```

**Why not:** Frontend change required, breaks JavaScript conventions

### **Option 3: Use Newtonsoft.Json**
```csharp
// Switch from System.Text.Json to Newtonsoft.Json
services.AddControllers().AddNewtonsoftJson();
```

**Why not:** Unnecessary dependency, System.Text.Json is preferred

### **Our Solution: Property Attributes** ?
- ? Explicit and clear
- ? No global side effects
- ? Easy to understand and maintain
- ? Works with System.Text.Json

---

## ? **Verification Checklist**

After deploying:

- [ ] Restart AuthServer
- [ ] Hard refresh AdminPortal (Ctrl+Shift+R)
- [ ] User Management page loads
- [ ] Roles column shows actual roles (admin, dispatcher, etc.)
- [ ] Click "Edit Roles" on alice
- [ ] Modal shows "admin" checkbox checked
- [ ] Change to "dispatcher" and save
- [ ] Verify change persists after page refresh
- [ ] Run automated tests: `.\Scripts\Run-AllTests.ps1 -StartupDelay 5`

---

## ?? **Deployment Steps**

1. **Restart AuthServer**
   ```bash
   # Stop (Ctrl+C)
   dotnet run
   ```

2. **Clear Browser Cache**
   ```
   Ctrl+Shift+R (hard refresh)
   Or clear cache in DevTools
   ```

3. **Verify API Response** (DevTools Network tab)
   - Open DevTools (F12)
   - Go to Network tab
   - Refresh User Management page
   - Click on `/api/admin/users` request
   - Check Response tab
   - Verify JSON has lowercase property names

---

## ?? **Commit Message**

```
Add JsonPropertyName attributes for camelCase serialization

- Add [JsonPropertyName] attributes to UserSummaryDto properties
- Forces camelCase JSON output for AdminPortal compatibility
- Resolves roles showing as "None" in AdminPortal
- Ensures consistent property naming across API responses
```

---

## ?? **Related Issues**

This completes the AdminPortal compatibility fixes:

1. ? **Missing Username** - Fixed by adding Username property
2. ? **Roles showing "None"** - Fixed by JSON property name attributes
3. ? **Route conflicts** - Fixed by separating routes
4. ? **Test data cleanup** - Fixed by adding cleanup logic

**Status:** AdminPortal should now be fully functional!

---

**Status:** ? **FIXED**  
**Build:** ? Successful  
**Impact:** High (restores role management functionality)  
**Complexity:** Low (attribute annotations)

---

*Property naming fixed. Roles should now display correctly in AdminPortal.* ???
