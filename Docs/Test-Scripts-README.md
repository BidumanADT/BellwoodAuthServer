# AuthServer Phase 2 - Test Scripts

**Purpose:** Automated testing of Phase 2 functionality  
**Date:** January 13, 2026  
**Status:** ? Ready to Use

---

## ?? What These Scripts Test

### Core Phase 2 Features

1. **Dispatcher Role**
   - Login with dispatcher credentials
   - Verify JWT contains correct role claim
   - Verify email claim present

2. **Authorization Policies**
   - AdminOnly: Dispatchers denied admin endpoints
   - Admin access still works

3. **Role Assignment**
   - Admin can change user roles
   - Mutually exclusive role assignment
   - Users must re-login to get new role

4. **Security**
   - Dispatchers cannot assign roles
   - Invalid roles rejected
   - 403/401 responses for unauthorized access

---

## ?? Usage

### PowerShell (Windows)

```powershell
# Make sure AuthServer is running on https://localhost:5001
cd C:\Users\sgtad\source\repos\BellwoodAuthServer

# Run the test script
.\test-phase2.ps1
```

### Bash (Mac/Linux)

```bash
# Make sure AuthServer is running on https://localhost:5001
cd /path/to/BellwoodAuthServer

# Make script executable
chmod +x test-phase2.sh

# Run the test script
./test-phase2.sh
```

---

## ?? Test Coverage

| Test # | Feature | What It Checks |
|--------|---------|----------------|
| 1 | Dispatcher Login | JWT contains 'dispatcher' role |
| 2 | Admin Login | JWT contains 'admin' role |
| 3 | AdminOnly Policy | Dispatcher denied admin endpoints (403) |
| 4 | Admin Access | Admin can access admin endpoints (200) |
| 5 | Role Assignment | Admin can promote user to dispatcher |
| 6 | Role Verification | New role appears in JWT after re-login |
| 7 | Policy Enforcement | New dispatcher denied admin access |
| 8 | Security | Dispatcher cannot assign roles |
| 9 | Validation | Invalid roles rejected (400) |
| 10 | Role Change | Admin can demote dispatcher back to admin |
| 11 | Diagnostics | User info endpoint works |
| 12 | Health | Server health check responds |

---

## ? Expected Output

### Successful Run

```
??????????????????????????????????????????????????????????????
?         AuthServer Phase 2 - Functional Tests             ?
??????????????????????????????????????????????????????????????

Server: https://localhost:5001
Date: 2026-01-13 14:30:00

???????????????????????????????????????????????????????
TEST 1: Dispatcher Login
???????????????????????????????????????????????????????
? PASS: Dispatcher login successful, role claim is 'dispatcher'
? INFO: Email claim: diana.dispatcher@bellwood.example

[... more tests ...]

??????????????????????????????????????????????????????????????
?                    TEST SUMMARY                            ?
??????????????????????????????????????????????????????????????

Tests Run:    12
Tests Passed: 12
Tests Failed: 0

??????????????????????????????????????????????????????????????
?           ? ALL TESTS PASSED - PHASE 2 READY!             ?
??????????????????????????????????????????????????????????????
```

---

## ?? Prerequisites

### PowerShell Script
- PowerShell 5.1 or later
- AuthServer running on https://localhost:5001
- .NET 8.0 SDK installed

### Bash Script
- Bash shell
- `curl` command available
- `jq` command available (install with `brew install jq` on Mac)
- AuthServer running on https://localhost:5001

---

## ??? Configuration

Both scripts use these default values (edit at top of file if needed):

```
AuthServer URL:    https://localhost:5001
Admin Username:    alice
Admin Password:    password
Dispatcher User:   diana
Dispatcher Pass:   password
Test User:         bob (will be changed to dispatcher and back)
```

---

## ?? Troubleshooting

### AuthServer Not Running

**Error:**
```
Connection refused or timeout
```

**Solution:**
```bash
# Start AuthServer
cd BellwoodAuthServer
dotnet run
```

### SSL Certificate Errors (PowerShell)

The PowerShell script automatically accepts self-signed certificates for localhost testing. If you see certificate errors, the script handles them.

### jq Not Found (Bash)

**Error:**
```
Error: jq is not installed
```

**Solution:**
```bash
# Mac
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Windows (WSL)
sudo apt-get install jq
```

### Tests Failing

**Check:**
1. AuthServer is running
2. Database is seeded (test users exist)
3. Phase 2 code is deployed
4. Server URL matches configuration

**View logs:**
```bash
# Check AuthServer console output for errors
```

---

## ?? Test Scenarios Explained

### Test 1-2: Login Tests
- Verify dispatcher and admin users can login
- Verify JWT tokens have correct role claims

### Test 3-4: Policy Enforcement
- Verify AdminOnly policy blocks dispatchers
- Verify AdminOnly policy allows admins

### Test 5-7: Role Assignment
- Admin changes bob from admin to dispatcher
- Bob re-logins and gets new role
- Bob (now dispatcher) cannot access admin endpoints

### Test 8: Security Check
- Dispatcher cannot call role assignment endpoint
- Ensures least privilege

### Test 9: Validation
- Invalid role names rejected
- Helpful error messages returned

### Test 10: Cleanup
- Restore bob to admin role
- Ensures repeatable tests

### Test 11-12: Diagnostics
- Verify diagnostic endpoints work
- Health check responds

---

## ?? Success Criteria

**All tests must pass for Phase 2 sign-off:**

- [x] Dispatcher can login
- [x] Dispatcher has correct JWT claims
- [x] Dispatchers blocked from admin endpoints
- [x] Admins retain full access
- [x] Role assignment works
- [x] Roles are mutually exclusive
- [x] Security enforced (dispatchers can't assign roles)
- [x] Validation works
- [x] Diagnostic endpoints functional

---

## ?? Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All tests passed |
| 1 | One or more tests failed |

**Use in CI/CD:**
```bash
./test-phase2.sh
if [ $? -eq 0 ]; then
    echo "Phase 2 tests passed, proceeding with deployment"
else
    echo "Phase 2 tests failed, blocking deployment"
    exit 1
fi
```

---

## ?? Running in CI/CD

### GitHub Actions Example

```yaml
- name: Run Phase 2 Tests
  run: |
    dotnet run --project BellwoodAuthServer &
    sleep 5
    ./test-phase2.sh
```

### Azure DevOps Example

```yaml
- script: |
    dotnet run --project BellwoodAuthServer &
    sleep 5
    ./test-phase2.sh
  displayName: 'Run Phase 2 Tests'
```

---

## ?? Related Documentation

- `Docs/AuthServer-Phase2.md` - Complete implementation guide
- `Docs/AuthServer-Phase2-Complete.md` - Completion summary
- `Docs/AdminAPI-Phase2-Reference.md` - Integration reference

---

## ?? Getting Help

**If tests fail:**
1. Check AuthServer console for errors
2. Verify all Phase 2 code is deployed
3. Ensure test users exist (alice, bob, chris, charlie, diana)
4. Check server URL matches configuration

**If you need to modify tests:**
1. Edit configuration section at top of script
2. Add new test using the pattern:
   ```bash
   Print-Test "13" "Test Description"
   # Test code here
   Print-Pass "Test passed"
   ```

---

**Status:** ? Ready for Phase 2 Testing  
**Maintained By:** AuthServer Team  
**Last Updated:** January 13, 2026

---

*These scripts provide comprehensive automated testing of all Phase 2 functionality. Run them before deploying to ensure everything works correctly.* ???
