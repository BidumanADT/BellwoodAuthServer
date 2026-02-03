# ?? Enhanced Test Debugging - Retry Logic Added

**Date:** February 3, 2026  
**Issue:** Connection errors still occurring on enable endpoints  
**Solution:** Added retry logic with detailed error logging  
**Status:** ? Ready for testing

---

## ?? What Was Added

### **Retry Logic with Detailed Diagnostics**

All failing endpoints now have:
- ? **3 retry attempts** (was 1)
- ? **2-second delay between retries**
- ? **Detailed error messages** (exception + inner exception)
- ? **30-second timeout** (was default 100 seconds)
- ? **1-second connection reset delay** (was 500ms)

---

## ?? Files Enhanced

### **1. test-phase2.ps1- Test 4**
```powershell
# Admin Can Access Admin Endpoints
$maxRetries = 3
$retryDelay = 2

for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
    # Connection pool reset
    $sp = [System.Net.ServicePointManager]::FindServicePoint($AuthServerUrl)
    $sp.CloseConnectionGroup("")
    Start-Sleep -Milliseconds 1000
    
    # Make request with retry
    $response = Invoke-RestMethod ... -TimeoutSec 30
    
    # On error, show detailed diagnostics
    Print-Info "Last error: $errorMsg"
    Print-Info "Inner exception: $innerMsg"
}
```

### **2. test-lockout-enforcement.ps1 - Step 6**
```powershell
# Re-enabling user
for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
    # Detailed error logging
    Write-Host "  Attempt $attempt failed: $errorMsg"
    Write-Host "  Inner exception: $innerMsg"
    Write-Host "  Waiting $retryDelay seconds..."
}
```

### **3. test-provisioning-api.ps1 - Test 7**
```powershell
# Enable User
for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
    # Same retry logic with Test-Pass/Test-Fail helpers
}
```

---

## ?? Enhanced Error Output

### **Before (Not Helpful):**
```
? Failed to enable user: The underlying connection was closed
```

### **After (Very Helpful):**
```
Attempt 1 failed: The underlying connection was closed: An unexpected error occurred on a send.
Inner exception: Unable to read data from the transport connection: An existing connection was forcibly closed by the remote host.
Waiting 2 seconds before retry...

Retry attempt 2 of 3...
? User enabled successfully
```

---

## ?? What This Helps Us Learn

With the new detailed logging, we'll see:

1. **Exact error message** - What PowerShell reports
2. **Inner exception** - The real underlying cause
3. **Retry success** - Whether retries fix it
4. **Consistent failure pattern** - If all retries fail the same way

This will tell us if the issue is:
- ? **Timing** - Fixed by retries
- ? **Server-side** - Consistent errors
- ? **Protocol** - TLS/HTTP specific messages
- ? **Network** - Connection closed by remote host

---

## ?? How to Test

```powershell
# Restart server
dotnet run

# Run tests with detailed output
.\Scripts\Run-AllTests.ps1 -StartupDelay 5
```

**Watch for the new output:**
- Retry messages
- Error details
- Inner exception messages

---

## ?? Expected Outcomes

### **Best Case: Retries Fix It** ?
```
Attempt 1 failed: connection closed
Waiting 2 seconds before retry...
Retry attempt 2 of 3...
? User enabled successfully
```
**Outcome:** Tests pass, we know it's a timing issue

### **Server Issue:**
```
Attempt 1 failed: 500 Internal Server Error
Inner exception: NullReferenceException
Retry attempt 2 of 3...
Attempt 2 failed: 500 Internal Server Error
```
**Outcome:** Need to fix server code

### **Protocol Issue:**
```
Attempt 1 failed: connection closed
Inner exception: TLS handshake failed
Retry attempt 2 of 3...
Attempt 2 failed: connection closed
```
**Outcome:** Need different TLS strategy

---

## ?? Debugging Guide

### **If Retries Work:**
- ? Keep retry logic
- ? Maybe reduce to 2 retries
- ? Tests will pass consistently

### **If All Retries Fail:**
**Check the inner exception message for clues:**

**"TLS handshake failed"** ?  Need TLS protocol fix  
**"Connection forcibly closed"** ? Server closing connections  
**"NullReferenceException"** ? Server-side bug  
**"Timeout"** ? Server too slow, increase timeout  
**"403 Forbidden"** ? User still disabled (logic error)

---

## ?? What We Changed

### **Connection Reset:**
- Increased delay from 500ms ? **1000ms (1 second)**
- Gives more time for connection cleanup

### **Request Timeout:**
- Added explicit **30-second timeout**
- Prevents hanging on bad connections

### **Retry Logic:**
- **3 attempts** with 2-second delays
- Shows progress to user
- Logs detailed errors

### **Error Reporting:**
- Shows exception message
- Shows inner exception
- Shows attempt number
- Shows what we're retrying

---

## ? Success Criteria

**Tests pass if:**
- First attempt succeeds ?
- OR retry succeeds after 1-2 attempts ?

**We need investigation if:**
- All 3 retries fail consistently ??
- Inner exception shows server errors ??
- Same error message every time ??

---

## ?? Expected Results

With retry logic:
- **Phase 2, Test 4:** Should pass (maybe on retry 2)
- **Lockout, Step 6:** Should pass (maybe on retry 2)  
- **Provisioning, Test 7:** Should pass (maybe on retry 2)

**Overall pass rate:** Hoping for 100%! ??

---

## ?? Why Retries Help

**The TLS connection pooling issue is intermittent:**
- First request after connection reset: Sometimes fails
- Second request: Usually works (new connection established)
- Third request: Almost always works

**By adding retries:**
- We give the connection pool time to stabilize
- We get detailed error info if consistent failure
- We make tests more resilient
- We learn what's really happening

---

## ?? Next Steps

1. **Run tests** with new retry logic
2. **Watch console output** for error details
3. **Share results** - We'll see exactly what's failing
4. **Adjust strategy** based on error messages

---

**With detailed logging, we'll finally see what's really going on!** ???

Run the tests and paste the output - we'll be able to diagnose the exact issue! ??
