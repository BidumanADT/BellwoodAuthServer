# ?? Test User Conflict Resolution Guide

**Issue:** Tests failing with "409 Conflict" errors  
**Cause:** Test users from previous runs still exist in database  
**Status:** ? FIXED

---

## ?? Quick Solutions

### **Solution 1: Run Cleanup Script (RECOMMENDED)**

Before running tests:

```powershell
# Clean up test users (enables them for reuse)
.\Scripts\Cleanup-TestUsers.ps1

# Then run tests
.\Scripts\Run-AllTests.ps1 -StartupDelay 5
```

---

### **Solution 2: Delete Database (Nuclear Option)**

```powershell
# Stop server (Ctrl+C)

# Delete database
Remove-Item .\authserver.db

# Restart server (recreates and reseeds database)
dotnet run

# Run tests
.\Scripts\Run-AllTests.ps1 -StartupDelay 5
```

---

### **Solution 3: Tests Now Auto-Handle Existing Users**

The test scripts have been updated to:
- ? Check if test user exists
- ? Reuse existing user if found
- ? Enable user if disabled
- ? Continue testing normally

**This means you can just re-run tests:**
```powershell
.\Scripts\Run-AllTests.ps1 -StartupDelay 5
```

---

## ?? What Changed

### **Before (Broke on Rerun)**
```
Test 2: Create User
  ? Failed to create user: 409 Conflict
  (User may already exist - continuing...)

Test 3: Verify User Can Login
  ? New user cannot login: 403 Forbidden
  (Because user is still disabled from last run)
```

### **After (Works on Rerun)**
```
Test 2: Create User
  ? Using existing user (ID: abc-123)
  (Auto-enabled if was disabled)

Test 3: Verify User Can Login
  ? New user can login successfully
  (Works because user was enabled)
```

---

## ??? Updated Test Scripts

### **1. test-lockout-enforcement.ps1**
- Checks for existing `lockouttest@example.com`
- Reuses if found and enables it
- Only creates new user if doesn't exist

### **2. test-role-normalization.ps1**
- Checks for `roletest1`, `roletest2`, `roletest3`
- Fetches existing users on 409 conflict
- Validates roles on existing users

### **3. test-provisioning-api.ps1**
- Checks for existing `provisiontest@example.com`
- Enables user if disabled
- Reuses for all tests

---

## ?? New Cleanup Script

**File:** `Scripts/Cleanup-TestUsers.ps1`

**What It Does:**
- Finds all test users
- Shows which are enabled/disabled
- Enables all disabled test users
- Prepares database for clean test run

**Usage:**
```powershell
# Preview what would be cleaned
.\Scripts\Cleanup-TestUsers.ps1 -WhatIf

# Actually clean up
.\Scripts\Cleanup-TestUsers.ps1
```

**Test Users It Manages:**
- `lockouttest@example.com`
- `roletest1@example.com`
- `roletest2@example.com`
- `roletest3@example.com`
- `roletest4@example.com`
- `provisiontest@example.com`

---

## ?? How to Identify Test User Issues

### **Symptom 1: 409 Conflict Errors**
```
? Failed to create test user: (409) Conflict
```

**Cause:** User already exists  
**Fix:** Run cleanup script or tests will auto-handle

### **Symptom 2: 403 Forbidden on Test User Login**
```
? User login failed unexpectedly: (403) Forbidden
```

**Cause:** Test user exists but is disabled from previous run  
**Fix:** Run cleanup script to enable, or tests will auto-enable

### **Symptom 3: Skipped Tests**
```
? Test skipped (no test user)
```

**Cause:** User creation failed, no user ID available  
**Fix:** Run cleanup script or restart with fresh database

---

## ?? Test User Lifecycle

### **Normal Flow (First Run)**
1. Test creates user
2. Test uses user
3. Test disables user (lockout tests)
4. Test completes
5. **User remains in database**

### **Problem Flow (Second Run - OLD)**
1. Test tries to create user
2. ? 409 Conflict (user exists)
3. ? Test fails
4. ? Subsequent tests skip

### **Fixed Flow (Second Run - NEW)**
1. Test tries to create user
2. ?? 409 Conflict detected
3. ? Fetch existing user
4. ? Enable if disabled
5. ? Continue testing

---

## ?? Best Practices

### **Development Workflow**
```powershell
# Run tests multiple times without cleanup
.\Scripts\Run-AllTests.ps1 -StartupDelay 5
.\Scripts\Run-AllTests.ps1 -StartupDelay 5
# Tests auto-handle existing users
```

### **Clean Slate Workflow**
```powershell
# Clean database
.\Scripts\Cleanup-TestUsers.ps1

# Run tests
.\Scripts\Run-AllTests.ps1 -StartupDelay 5
```

### **Nuclear Reset Workflow**
```powershell
# Delete database completely
Remove-Item .\authserver.db

# Restart server
dotnet run

# Run tests
.\Scripts\Run-AllTests.ps1 -StartupDelay 5
```

---

## ? Verification Checklist

**After implementing fixes:**

- [ ] Run tests twice in a row - both should pass
- [ ] Run cleanup script - shows test users
- [ ] Check test output - no "409 Conflict" failures
- [ ] Check test output - no "skipped" tests
- [ ] All tests pass on first AND second run

---

## ?? Manual Cleanup (If Needed)

### **Check Current Test Users**
```powershell
# Login as admin
$response = Invoke-RestMethod -Uri "https://localhost:5001/login" `
    -Method Post `
    -ContentType "application/json" `
    -Body '{"username":"alice","password":"password"}'

$token = $response.token

# Get all users
$users = Invoke-RestMethod -Uri "https://localhost:5001/api/admin/provisioning?take=100" `
    -Method Get `
    -Headers @{Authorization="Bearer $token"}

# Show test users
$users | Where-Object { $_.email -like "*test*" } | Format-Table email,roles,isDisabled
```

### **Enable Specific User**
```powershell
# Use user ID from above
$userId = "USER-ID-HERE"

Invoke-RestMethod -Uri "https://localhost:5001/api/admin/provisioning/$userId/enable" `
    -Method Put `
    -Headers @{Authorization="Bearer $token"}
```

---

## ?? Summary

**Problem:** Tests fail on rerun due to existing users  
**Root Cause:** No cleanup between test runs  
**Solution 1:** Cleanup script (enables test users)  
**Solution 2:** Tests auto-handle existing users  
**Solution 3:** Delete database (nuclear option)

**Recommended:** Just rerun tests - they'll handle it! ?

---

*Test user management fixed and automated.* ???
