# AuthServer Test Suite

**PowerShell 5.1+ Compatible Test Suite**

Comprehensive automated testing for AuthServer covering all phases and functionality.

---

## ?? Quick Start

### Run All Tests

```powershell
.\Scripts\Run-AllTests.ps1
```

This will execute the complete test suite and generate a detailed report.

---

## ?? Test Suites

### **1. Phase 1 - Basic Authentication**
**File:** `test-phase1-auth.ps1`

**Tests:**
- Health check endpoint
- Admin user login
- Invalid credentials rejection
- Missing parameter validation
- JWT token claims validation
- Alternate login endpoint
- Booker user login
- Driver user login

**Run Individually:**
```powershell
.\Scripts\test-phase1-auth.ps1
```

---

### **2. Phase 2 - Role-Based Access Control**
**File:** `test-phase2.ps1`

**Tests:**
- Dispatcher login with correct role
- Admin access to admin endpoints
- Dispatcher denied access to admin endpoints
- Role assignment (admin-only)
- Role changes persist
- Authorization policy enforcement
- Dispatcher cannot assign roles
- Invalid role rejection
- User diagnostic endpoints

**Run Individually:**
```powershell
.\Scripts\test-phase2.ps1
```

---

### **3. Lockout Enforcement**
**File:** `test-lockout-enforcement.ps1`

**Tests:**
- User creation
- Initial login success
- Disable user
- Login blocked for disabled user (403)
- Enable user
- Login success after re-enable

**Run Individually:**
```powershell
.\Scripts\test-lockout-enforcement.ps1
```

---

### **4. Role Normalization**
**File:** `test-role-normalization.ps1`

**Tests:**
- Mixed case roles normalized to lowercase
- Role updates with mixed case
- All uppercase roles normalized
- Multiple mixed case roles
- Invalid role validation still works

**Run Individually:**
```powershell
.\Scripts\test-role-normalization.ps1
```

---

### **5. User Provisioning API**
**File:** `test-provisioning-api.ps1`

**Tests:**
- List users (GET)
- Create user (POST)
- Verify new user can login
- Update user roles (PUT)
- Disable user
- Verify disabled user cannot login
- Enable user
- Verify enabled user can login
- Duplicate email rejection
- Pagination parameters

**Run Individually:**
```powershell
.\Scripts\test-provisioning-api.ps1
```

---

## ??? Master Script Options

### Run All Tests
```powershell
.\Scripts\Run-AllTests.ps1
```

### Skip Specific Suites
```powershell
# Skip Phase 1 tests
.\Scripts\Run-AllTests.ps1 -SkipPhase1

# Skip Phase 2 tests
.\Scripts\Run-AllTests.ps1 -SkipPhase2

# Skip lockout tests
.\Scripts\Run-AllTests.ps1 -SkipLockout

# Skip role normalization tests
.\Scripts\Run-AllTests.ps1 -SkipRoles

# Skip provisioning tests
.\Scripts\Run-AllTests.ps1 -SkipProvisioning
```

### Stop on First Error
```powershell
.\Scripts\Run-AllTests.ps1 -StopOnError
```

### Custom Server URL
```powershell
.\Scripts\Run-AllTests.ps1 -AuthServerUrl "https://authserver.example.com"
```

### Combine Options
```powershell
.\Scripts\Run-AllTests.ps1 -SkipPhase1 -StopOnError -AuthServerUrl "https://localhost:5001"
```

---

## ?? Test Reports

Test results are automatically saved to:
```
Scripts/test-report-YYYYMMDD-HHMMSS.txt
```

Example:
```
Scripts/test-report-20260202-143022.txt
```

---

## ? Prerequisites

### 1. AuthServer Running
```powershell
# In AuthServer directory
dotnet run
```

### 2. PowerShell 5.1+
```powershell
# Check version
$PSVersionTable.PSVersion
```

### 3. Network Access
- Server must be accessible at configured URL (default: https://localhost:5001)
- SSL certificate warnings are automatically suppressed for localhost

---

## ?? Expected Results

### All Tests Passing
```
??????????????????????????????????????????????????????????????
?              ? ALL TESTS PASSED!                           ?
??????????????????????????????????????????????????????????????

Test Results:
  Total Tests:   5
  Passed:        5
  Failed:        0
  Skipped:       0

  Pass Rate:     100%
```

### Some Tests Failing
```
??????????????????????????????????????????????????????????????
?              ? SOME TESTS FAILED                           ?
??????????????????????????????????????????????????????????????

Test Results:
  Total Tests:   5
  Passed:        4
  Failed:        1
  Skipped:       0

  Pass Rate:     80%
```

---

## ?? Troubleshooting

### Server Not Running
```
? Server is not responding!

Please start the AuthServer:
  dotnet run
```

**Solution:** Start AuthServer before running tests

### SSL Certificate Errors
The test scripts automatically suppress SSL warnings for localhost testing. If you see certificate errors, ensure you're using the provided test scripts which include certificate policy configuration.

### Test User Already Exists
Some tests create users (e.g., `lockouttest@example.com`, `provisiontest@example.com`). If tests fail due to existing users, you can:

1. **Delete the SQLite database** and restart server (reseeds data)
2. **Manually delete test users** via API
3. **Change test email** in the individual test script

### Authentication Failures
If admin login fails:
1. Verify seed data is correct (alice/password)
2. Check database was migrated correctly
3. Verify server is running without errors

---

## ?? Test Coverage

| Category | Coverage | Tests |
|----------|----------|-------|
| Authentication | ? Complete | 8 tests |
| Authorization | ? Complete | 12 tests |
| Role Management | ? Complete | 5 tests |
| User Lifecycle | ? Complete | 10 tests |
| Security | ? Complete | 7 tests |
| **Total** | **? 42+ tests** | **Across 5 suites** |

---

## ?? Best Practices

### Before Deployment
```powershell
# Run full test suite
.\Scripts\Run-AllTests.ps1

# Verify all tests pass
# Review test report
```

### During Development
```powershell
# Run specific suite you're working on
.\Scripts\test-phase2.ps1

# Or run all with stop on error for faster feedback
.\Scripts\Run-AllTests.ps1 -StopOnError
```

### CI/CD Integration
```powershell
# In your CI/CD pipeline
.\Scripts\Run-AllTests.ps1
exit $LASTEXITCODE
```

---

## ?? Adding New Tests

### 1. Create New Test Script
```powershell
# Scripts/test-new-feature.ps1
param([string]$AuthServerUrl = "https://localhost:5001")

# Your test code here
# Use exit 0 for success, exit 1 for failure
```

### 2. Add to Master Script
Edit `Run-AllTests.ps1` and add to `$testSuites` array:
```powershell
@{
    Name = "New Feature Tests"
    Script = "test-new-feature.ps1"
    Skip = $SkipNewFeature
}
```

### 3. Add Parameter
```powershell
param(
    # ...existing params...
    [switch]$SkipNewFeature
)
```

---

## ?? Related Documentation

- **Phase 1 Documentation:** `Docs/AuthServer-Phase1.md`
- **Phase 2 Documentation:** `Docs/AuthServer-Phase2.md`
- **API Reference:** `Docs/AdminAPI-Phase2-Reference.md`
- **Implementation Reports:** `Docs/All-Fixes-Implemented.md`

---

## ?? Test Suite Summary

**Total Scripts:** 6
- 1 Master orchestrator
- 5 Test suite scripts

**Total Tests:** 42+

**PowerShell Version:** 5.1+ compatible

**Execution Time:** ~2-3 minutes (full suite)

**Report Generation:** Automatic

**Exit Codes:**
- `0` = All tests passed
- `1` = Some tests failed

---

## ? Features

- ? PowerShell 5.1+ compatible
- ? Automatic SSL suppression for localhost
- ? Detailed test reports
- ? Color-coded output
- ? Individual suite execution
- ? Master orchestrator script
- ? Flexible skip options
- ? Stop-on-error support
- ? Automatic report generation
- ? Exit code integration for CI/CD

---

**Ready to test!** ??

Run `.\Scripts\Run-AllTests.ps1` to get started!
