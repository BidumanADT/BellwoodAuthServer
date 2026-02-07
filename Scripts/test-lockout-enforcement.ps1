# Test Script - Lockout Enforcement Verification
# Tests the critical lockout fix to ensure disabled users cannot login

# Configuration
$AuthServerUrl = "https://localhost:5001"
$AdminUser = "alice"
$AdminPass = "password"

# Test user credentials
$TestEmail = "lockouttest@example.com"
$TestPassword = "Test123!"

# Suppress SSL warnings - check if type already exists first
if (-not ([System.Management.Automation.PSTypeName]'TrustAllCertsPolicy').Type) {
    Add-Type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
}
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls

$script:TestsPassed = 0
$script:TestsFailed = 0

Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host "?         Lockout Enforcement - Critical Test               ?" -ForegroundColor Cyan
Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host ""

# Step 1: Login as admin
Write-Host "Step 1: Getting admin token..." -ForegroundColor Yellow
try {
    $body = @{
        username = $AdminUser
        password = $AdminPass
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    $script:AdminToken = $response.token
    Write-Host "? Admin token obtained" -ForegroundColor Green
}
catch {
    Write-Host "? Failed to get admin token: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 2: Create test user
Write-Host "`nStep 2: Creating test user..." -ForegroundColor Yellow
try {
    $headers = @{
        Authorization = "Bearer $script:AdminToken"
    }
    
    # First, try to delete the user if it exists (cleanup from previous run)
    try {
        $existingUsers = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users?take=100" `
            -Method Get `
            -Headers $headers
        
        $existingUser = $existingUsers | Where-Object { $_.email -eq $TestEmail }
        if ($existingUser) {
            Write-Host "  Cleaning up existing test user from previous run..." -ForegroundColor Gray
            # Note: We don't have a delete endpoint, so we'll skip creation if exists
            $script:TestUserId = $existingUser.userId
            Write-Host "  ? Using existing test user (ID: $script:TestUserId)" -ForegroundColor Green
            
            # Make sure user is enabled for testing
            try {
                Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users/$script:TestUserId/enable" `
                    -Method Put `
                    -Headers $headers | Out-Null
            }
            catch { }
        }
    }
    catch {
        # Ignore errors checking for existing user
    }
    
    # Only create if we don't have a user ID
    if (-not $script:TestUserId) {
        $body = @{
            email = $TestEmail
            tempPassword = $TestPassword
            roles = @("booker")
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users" `
            -Method Post `
            -Headers $headers `
            -ContentType "application/json" `
            -Body $body

        $script:TestUserId = $response.userId
        Write-Host "  ? Test user created (ID: $script:TestUserId)" -ForegroundColor Green
    }
}
catch {
    Write-Host "  ? Failed to create test user: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    This might be expected if user exists from previous run" -ForegroundColor Yellow
}

# Step 3: Verify user can login
Write-Host "`nStep 3: Testing login (should succeed)..." -ForegroundColor Yellow
try {
    $body = @{
        username = $TestEmail
        password = $TestPassword
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    Write-Host "? User login successful (got token)" -ForegroundColor Green
}
catch {
    Write-Host "? User login failed unexpectedly: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 4: Disable user
Write-Host "`nStep 4: Disabling user..." -ForegroundColor Yellow
if ($script:TestUserId) {
    try {
        $headers = @{
            Authorization = "Bearer $script:AdminToken"
        }

        $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users/$script:TestUserId/disable" `
            -Method Put `
            -Headers $headers

        if ($response.isDisabled -eq $true) {
            Write-Host "? User disabled successfully (isDisabled: $($response.isDisabled))" -ForegroundColor Green
        }
        else {
            Write-Host "? User disable returned unexpected value: isDisabled = $($response.isDisabled)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "? Failed to disable user: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "? Skipping (no user ID available)" -ForegroundColor Yellow
}

# Step 5: CRITICAL TEST - Verify login is blocked
Write-Host "`nStep 5: CRITICAL TEST - Verify login blocked..." -ForegroundColor Yellow
Write-Host "  (This is the lockout enforcement test)" -ForegroundColor Cyan
try {
    $body = @{
        username = $TestEmail
        password = $TestPassword
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    Write-Host "? CRITICAL FAILURE: Disabled user was able to login!" -ForegroundColor Red
    Write-Host "  Lockout enforcement is NOT working!" -ForegroundColor Red
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 403) {
        Write-Host "? SUCCESS: Login blocked with 403 Forbidden" -ForegroundColor Green
        Write-Host "  Lockout enforcement is WORKING!" -ForegroundColor Green
        
        # Try to get error message
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            Write-Host "  Error message: $errorBody" -ForegroundColor Gray
        }
        catch { }
    }
    elseif ($statusCode -eq 401) {
        Write-Host "? Login blocked with 401 Unauthorized" -ForegroundColor Yellow
        Write-Host "  Expected 403 Forbidden for disabled account" -ForegroundColor Yellow
    }
    else {
        Write-Host "? Login blocked with unexpected status: $statusCode" -ForegroundColor Yellow
    }
}

# Step 6: Enable user
Write-Host "`nStep 6: Re-enabling user..." -ForegroundColor Yellow
if ($script:TestUserId) {
    $maxRetries = 3
    $retryDelay = 2
    $success = $false
    
    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        try {
            if ($attempt -gt 1) {
                Write-Host "  Retry attempt $attempt of $maxRetries..." -ForegroundColor Gray
            }
            
            $headers = @{
                Authorization = "Bearer $script:AdminToken"
            }

            # Use WebRequest instead of RestMethod to avoid connection pooling issues
            $request = [System.Net.HttpWebRequest]::Create("$AuthServerUrl/api/admin/users/$script:TestUserId/enable")
            $request.Method = "PUT"
            $request.Headers.Add("Authorization", "Bearer $script:AdminToken")
            $request.KeepAlive = $false  # Don't reuse connection
            $request.Timeout = 30000
            
            $response = $request.GetResponse()
            $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
            $jsonResponse = $reader.ReadToEnd()
            $reader.Close()
            $response.Close()
            
            $data = $jsonResponse | ConvertFrom-Json

            if ($data.isDisabled -eq $false) {
                Write-Host "? User enabled successfully (isDisabled: $($data.isDisabled))" -ForegroundColor Green
                $success = $true
                break
            }
            else {
                Write-Host "? User enable returned unexpected value: isDisabled = $($data.isDisabled)" -ForegroundColor Yellow
                break
            }
        }
        catch {
            $errorMsg = $_.Exception.Message
            $innerMsg = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { "None" }
            
            if ($attempt -lt $maxRetries) {
                Write-Host "  Attempt $attempt failed: $errorMsg" -ForegroundColor Gray
                if ($innerMsg -ne "None") {
                    Write-Host "  Inner exception: $innerMsg" -ForegroundColor Gray
                }
                Write-Host "  Waiting $retryDelay seconds before retry..." -ForegroundColor Gray
                Start-Sleep -Seconds $retryDelay
            }
            else {
                Write-Host "? Failed to enable user after $maxRetries attempts" -ForegroundColor Red
                Write-Host "  Last error: $errorMsg" -ForegroundColor Gray
                if ($innerMsg -ne "None") {
                    Write-Host "  Inner exception: $innerMsg" -ForegroundColor Gray
                }
            }
        }
    }
}
else {
    Write-Host "? Skipping (no user ID available)" -ForegroundColor Yellow
}

# Step 7: Verify login works again
Write-Host "`nStep 7: Testing login after re-enable (should succeed)..." -ForegroundColor Yellow
try {
    $body = @{
        username = $TestEmail
        password = $TestPassword
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    Write-Host "? User login successful after re-enable (got token)" -ForegroundColor Green
}
catch {
    Write-Host "? User login failed after re-enable: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host "?                    TEST COMPLETE                           ?" -ForegroundColor Cyan
Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host ""
Write-Host "Lockout enforcement verification complete." -ForegroundColor Green
Write-Host "Review Step 5 for critical lockout test result." -ForegroundColor Yellow
Write-Host ""
