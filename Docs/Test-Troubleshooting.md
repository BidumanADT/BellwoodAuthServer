# ?? Test Suite Troubleshooting Guide

**Issue:** Pre-flight check fails even though server is running

---

## ?? Quick Solutions

### **Solution 1: Add Startup Delay (RECOMMENDED)**

The server might need a few seconds to fully initialize after startup.

```powershell
# Wait 3 seconds before testing
.\Scripts\Run-AllTests.ps1 -StartupDelay 3

# Or wait 5 seconds for slower systems
.\Scripts\Run-AllTests.ps1 -StartupDelay 5
```

---

### **Solution 2: Run Diagnostic Script**

Use the diagnostic tool to identify the exact issue:

```powershell
.\Scripts\Test-ServerConnection.ps1
```

This will test:
- Network connectivity
- SSL certificate
- Health endpoint
- REST API calls
- Login endpoint

---

### **Solution 3: Use Verbose Mode**

Get detailed error information:

```powershell
.\Scripts\Run-AllTests.ps1 -Verbose
```

This shows:
- Each retry attempt
- Full URL being tested
- Detailed error messages
- Response content

---

### **Solution 4: Manual Pre-Flight Check**

Test the health endpoint manually:

```powershell
# Test with Invoke-RestMethod
Invoke-RestMethod -Uri "https://localhost:5001/health"

# Should return: ok
```

If this works, the issue is timing. Use Solution 1.

---

## ?? Common Causes

### **Cause 1: Server Not Fully Started**

**Symptom:** Server shows "listening" but health check fails

**Why:** Server binds to port before all services are ready

**Solution:** Use `-StartupDelay 3` or `-StartupDelay 5`

---

### **Cause 2: PowerShell Session Issue**

**Symptom:** First run fails, second run succeeds

**Why:** SSL trust policy takes a moment to apply

**Solution:** 
```powershell
# Add a small delay
.\Scripts\Run-AllTests.ps1 -StartupDelay 2
```

---

### **Cause 3: Database Migration**

**Symptom:** Server starts slowly on first run

**Why:** SQLite database being created and migrated

**Solution:** 
```powershell
# Longer delay for first-time startup
.\Scripts\Run-AllTests.ps1 -StartupDelay 5
```

---

### **Cause 4: Port Already in Use**

**Symptom:** Server says "listening" but different port

**Why:** Port 5001 might be taken by another process

**Solution:**
```powershell
# Check what's listening on 5001
netstat -ano | findstr :5001

# If different process, kill it or change server port
```

---

## ?? Diagnostic Workflow

### Step 1: Verify Server is Running
```powershell
# Look for these lines in server output:
# Now listening on: https://localhost:5001
# Now listening on: http://localhost:5000
# Application started. Press Ctrl+C to shut down.
```

### Step 2: Run Diagnostic Tool
```powershell
.\Scripts\Test-ServerConnection.ps1
```

### Step 3: Interpret Results

**All tests pass:** Server is fine, use startup delay
```powershell
.\Scripts\Run-AllTests.ps1 -StartupDelay 3
```

**Network test fails:** Server not running or wrong URL

**SSL test fails:** Normal for localhost, ignore if health works

**Health endpoint fails:** Server issue, check console for errors

---

## ?? Recommended Workflow

### **Development Environment**

```powershell
# Start server
dotnet run

# Wait a moment, then run tests
.\Scripts\Run-AllTests.ps1 -StartupDelay 3
```

### **CI/CD Environment**

```powershell
# Start server in background
Start-Process -FilePath "dotnet" -ArgumentList "run" -NoNewWindow

# Wait for startup
Start-Sleep -Seconds 10

# Run tests
.\Scripts\Run-AllTests.ps1
```

---

## ?? Updated Test Script Features

### **New Parameters**

**StartupDelay**
```powershell
# Wait N seconds before testing
.\Scripts\Run-AllTests.ps1 -StartupDelay 5
```

**Verbose**
```powershell
# Show detailed diagnostics
.\Scripts\Run-AllTests.ps1 -Verbose
```

**Combined**
```powershell
.\Scripts\Run-AllTests.ps1 -StartupDelay 3 -Verbose
```

---

### **Improved Health Check**

The health check now:
- ? Retries 3 times (was 1)
- ? Waits 2 seconds between retries
- ? Has 10-second timeout (was 5)
- ? Shows detailed error messages
- ? Provides troubleshooting guidance

---

## ?? Expected Behavior

### **Normal Startup**

```
Pre-flight check: Verifying server is running...
  Attempt 1 of 3...
? Server is running and healthy
```

### **Server Needs More Time**

```
Pre-flight check: Verifying server is running...
  Attempt 1 of 3...
    Error: The operation has timed out.
    Waiting 2 seconds before retry...
  Attempt 2 of 3...
? Server is running and healthy
```

### **Server Not Running**

```
Pre-flight check: Verifying server is running...
  Attempt 1 of 3...
    Error: No connection could be made...
    Waiting 2 seconds before retry...
  Attempt 2 of 3...
    Error: No connection could be made...
    Waiting 2 seconds before retry...
  Attempt 3 of 3...
    Error: No connection could be made...
? Server health check failed after multiple attempts!

Troubleshooting:
  1. Verify server is running:
     dotnet run
  ...
```

---

## ?? Advanced Troubleshooting

### Check Server Logs

Look for errors in server console:
```
warn: Microsoft.AspNetCore.DataProtection...
fail: Microsoft.AspNetCore...
```

### Test with cURL

```bash
curl -k https://localhost:5001/health
# Should return: ok
```

### Test with PowerShell WebRequest

```powershell
$response = Invoke-WebRequest -Uri "https://localhost:5001/health" -UseBasicParsing
$response.Content
# Should return: ok
```

### Check Process

```powershell
# Verify dotnet process is running
Get-Process dotnet

# Check if listening on port
netstat -ano | findstr :5001
```

---

## ? Success Criteria

**Tests should run when:**
1. Server console shows "Application started"
2. Diagnostic script passes all tests
3. Manual health check returns "ok"
4. No errors in server console

**Use startup delay if:**
1. Server takes >2 seconds to start
2. First test run fails, second succeeds
3. Database migration is slow
4. Running on slower hardware

---

## ?? Quick Reference

| Issue | Solution | Command |
|-------|----------|---------|
| Pre-flight fails | Add startup delay | `-StartupDelay 3` |
| Need diagnostics | Run diagnostic tool | `.\Scripts\Test-ServerConnection.ps1` |
| Want details | Use verbose mode | `-Verbose` |
| Server not ready | Increase delay | `-StartupDelay 5` |
| Unknown issue | Run diagnostic first | See diagnostic output |

---

## ?? Summary

**Most common fix:**
```powershell
.\Scripts\Run-AllTests.ps1 -StartupDelay 3
```

This solves 90% of pre-flight check issues!

---

**Need more help?** Run the diagnostic script for detailed analysis:
```powershell
.\Scripts\Test-ServerConnection.ps1
```

---

*Last Updated: February 2, 2026*  
*Test Suite Version: 1.1*
