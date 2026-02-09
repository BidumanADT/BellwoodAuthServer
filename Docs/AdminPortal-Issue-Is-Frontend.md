# Roles Display Issue - AdminPortal Frontend Investigation

**Date:** February 7, 2026  
**Issue:** Roles showing as "None" in AdminPortal  
**Root Cause:** **AdminPortal frontend code issue, NOT AuthServer**  
**Status:** ?? **Issue is in AdminPortal, not AuthServer**

---

## ?? **Investigation Results**

### **AuthServer API Response (Verified)**

The AuthServer **IS** returning roles correctly:

```json
[{
  "userId": "914562c8-f4d2-4bb8-ad7a-f59526356132",
  "username": "alice",
  "email": "alice.admin@bellwood.example",
  "firstName": null,
  "lastName": null,
  "roles": ["admin"],          // ? CORRECT - lowercase, array populated
  "isDisabled": false,
  "createdAtUtc": null,
  "modifiedAtUtc": null
}]
```

### **Test Evidence**

Ran multiple tests confirming the API is working:

1. **test-api-response.ps1:** ? Roles present
2. **test-raw-json.ps1:** ? Roles present as array with "admin"
3. **test-exact-response.ps1:** ? Raw HTTP shows `"roles":["admin"]`

**All tests confirm:** The API returns `"roles": ["admin"]` correctly.

---

## ? **The Problem is in AdminPortal**

Since the API is returning correct data but AdminPortal shows "None", the issue must be in:

1. **AdminPortal's JavaScript/TypeScript code**
2. **How AdminPortal reads the response**
3. **How AdminPortal displays the data**

---

## ?? **Recommended Actions for AdminPortal Team**

### **1. Check Browser DevTools**

Open the AdminPortal and:
1. Press F12 to open DevTools
2. Go to Network tab
3. Refresh the User Management page
4. Click on the `/api/admin/users` request
5. Check the **Response** tab
6. Verify the JSON contains `"roles": ["admin"]`

### **2. Check AdminPortal JavaScript Code**

Look for code that displays roles in the table. Likely suspects:

**Possible Issue 1: Wrong property access**
```javascript
// WRONG - looking for capitalized property
user.Roles  // undefined

// CORRECT - should use lowercase
user.roles  // ["admin"]
```

**Possible Issue 2: Array handling**
```javascript
// WRONG - treating array as string
if (user.roles === "None") { ... }

// CORRECT - check if array has items
if (user.roles && user.roles.length > 0) {
    display(user.roles.join(', '));
} else {
    display("None");
}
```

**Possible Issue 3: Empty array check**
```javascript
// WRONG - empty array is truthy in JavaScript
if (user.roles) {  // This passes even for []
    display(user.roles[0]);  // undefined!
}

// CORRECT - check length
if (user.roles && user.roles.length > 0) {
    display(user.roles[0]);
}
```

### **3. Check AdminPortal TypeScript Interface**

If using TypeScript, check the User interface:

```typescript
interface User {
    userId: string;
    username: string;
    email: string;
    roles: string[];      // Should be string array
    isDisabled: boolean;
}
```

**Common mistake:**
```typescript
// WRONG - looking for singular "role" instead of plural "roles"
interface User {
    role: string;  // ? Should be "roles"
}
```

### **4. Check Data Mapping/Transformation**

Look for code that transforms the API response:

```javascript
// WRONG - losing the roles array
const mappedUser = {
    id: apiUser.userId,
    name: apiUser.username,
    // roles missing!
};

// CORRECT - include all fields
const mappedUser = {
    id: apiUser.userId,
    name: apiUser.username,
    roles: apiUser.roles,  // ? Include roles
};
```

---

## ?? **Testing in Browser Console**

In the AdminPortal, open browser console (F12) and run:

```javascript
// Fetch data directly in console
fetch('https://localhost:5001/api/admin/users?take=1', {
    headers: {
        'Authorization': 'Bearer YOUR_TOKEN_HERE'
    }
})
.then(r => r.json())
.then(users => {
    console.log('Users:', users);
    console.log('First user:', users[0]);
    console.log('Roles:', users[0].roles);
    console.log('Roles type:', typeof users[0].roles);
    console.log('Roles is array:', Array.isArray(users[0].roles));
});
```

**Expected output:**
```
Users: Array(1)
First user: {userId: "...", username: "alice", roles: Array(1), ...}
Roles: ["admin"]
Roles type: object
Roles is array: true
```

If this shows the roles correctly but the UI doesn't, the bug is in how the UI component reads/displays the data.

---

## ?? **Checklist for AdminPortal Team**

- [ ] Open Network tab in DevTools
- [ ] Verify `/api/admin/users` response contains `"roles": ["admin"]`
- [ ] Check JavaScript code that displays roles column
- [ ] Check if using correct property name (`roles` not `Roles` or `role`)
- [ ] Check if handling array correctly (not treating as string)
- [ ] Check TypeScript interface matches API response
- [ ] Test data fetch in browser console
- [ ] Look for data transformation code that might drop roles

---

## ?? **Common Code Patterns to Look For**

### **Table Display Code**

```javascript
// Example Vue.js template
<td>{{ user.roles ? user.roles.join(', ') : 'None' }}</td>

// Example React component
<td>{user.roles && user.roles.length > 0 ? user.roles.join(', ') : 'None'}</td>

// Example Angular template
<td>{{ user.roles?.length > 0 ? user.roles.join(', ') : 'None' }}</td>
```

### **Edit Roles Modal**

```javascript
// Check if current role is selected
const isSelected = user.roles && user.roles.includes(roleName);

// NOT this:
const isSelected = user.role === roleName;  // ? Wrong property
```

---

## ? **AuthServer Verification Complete**

**Test Results:**
- ? API returns correct JSON structure
- ? Property names are lowercase (camelCase)
- ? Roles field is populated with array
- ? Multiple users have different roles (admin, driver, dispatcher, etc.)
- ? JsonPropertyName attributes working correctly
- ? No global JSON configuration interfering

**AuthServer Status:** ? **WORKING CORRECTLY**

---

## ?? **Summary**

| Component | Status | Evidence |
|-----------|--------|----------|
| **AuthServer API** | ? Working | Returns `"roles":["admin"]` correctly |
| **JSON Serialization** | ? Working | camelCase property names |
| **Data Retrieval** | ? Working | PowerShell tests confirm data |
| **AdminPortal Frontend** | ? **Issue Here** | Displays "None" despite correct API response |

---

## ?? **Next Steps**

1. **AdminPortal Team:** Investigate frontend code using checklist above
2. **Test in browser console** to isolate where the data is lost
3. **Check for:**
   - Wrong property name access
   - Array handling issues
   - Data transformation bugs
   - TypeScript interface mismatches

---

## ?? **For AdminPortal Team**

**Question to ask:** "Where in our JavaScript/TypeScript code do we:
1. Receive the API response?
2. Map/transform the response data?
3. Store the user data in state?
4. Display the roles in the table?
5. Display the roles in the Edit modal?"

One of these steps is likely where the `roles` array is being dropped or mishandled.

---

**AuthServer is confirmed working. Issue is in AdminPortal frontend code.** ?

*Recommend AdminPortal team check their data handling and display logic.*
