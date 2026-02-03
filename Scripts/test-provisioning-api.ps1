# AuthServer - User Provisioning API Tests
# PowerShell 5.1 Compatible
# Tests the complete user provisioning API

param(
    [string]$AuthServerUrl = "https://localhost:5001"
)

# Suppress SSL warnings
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
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$script:TestsPassed = 0
$script:TestsFailed = 0

function Test-Pass {
    param([string]$Message)
    Write-Host "  ? $Message" -ForegroundColor Green
    $script:TestsPassed++
}

function Test-Fail {
    param([string]$Message)
    Write-Host "  ? $Message" -ForegroundColor Red
    $script:TestsFailed++
}

Write-Host "User Provisioning API Tests" -ForegroundColor Cyan
Write-Host ""

# Get admin token
Write-Host "Setup: Getting admin token..."
try {
    $body = @{
        username = "alice"
        password = "password"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    $script:AdminToken = $response.token
    Write-Host "  ? Admin token obtained" -ForegroundColor Green
}
catch {
    Write-Host "  ? Failed to get admin token: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 1: List Users (GET /api/admin/provisioning)
Write-Host "`nTest 1: List Users"
try {
    $headers = @{
        Authorization = "Bearer $script:AdminToken"
    }
    
    $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/provisioning" `
        -Method Get `
        -Headers $headers

    if ($response -is [Array]) {
        Test-Pass "User list retrieved successfully ($($response.Count) users)"
    }
    else {
        Test-Fail "Unexpected response format"
    }
}
catch {
    Test-Fail "Failed to list users: $($_.Exception.Message)"
}

# Test 2: Create User
Write-Host "`nTest 2: Create User"
try {
    $headers = @{
        Authorization = "Bearer $script:AdminToken"
    }
    
    $body = @{
        email = "provisiontest@example.com"
        tempPassword = "Test123!"
        roles = @("booker")
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/provisioning" `
        -Method Post `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $body

    if ($response.userId -and $response.email -eq "provisiontest@example.com") {
        Test-Pass "User created successfully (ID: $($response.userId))"
        $script:TestUserId = $response.userId
    }
    else {
        Test-Fail "User creation returned unexpected response"
    }
}
catch {
    Test-Fail "Failed to create user: $($_.Exception.Message)"
}

# Test 3: Verify User Can Login
Write-Host "`nTest 3: Verify New User Can Login"
try {
    $body = @{
        username = "provisiontest@example.com"
        password = "Test123!"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    if ($response.token) {
        Test-Pass "New user can login successfully"
    }
    else {
        Test-Fail "New user login succeeded but no token"
    }
}
catch {
    Test-Fail "New user cannot login: $($_.Exception.Message)"
}

# Test 4: Update User Roles
Write-Host "`nTest 4: Update User Roles"
if ($script:TestUserId) {
    try {
        $headers = @{
            Authorization = "Bearer $script:AdminToken"
        }
        
        $body = @{
            roles = @("driver")
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/provisioning/$script:TestUserId/roles" `
            -Method Put `
            -Headers $headers `
            -ContentType "application/json" `
            -Body $body

        if ($response.roles -contains "driver") {
            Test-Pass "User roles updated to driver"
        }
        else {
            Test-Fail "User roles not updated correctly: $($response.roles -join ', ')"
        }
    }
    catch {
        Test-Fail "Failed to update user roles: $($_.Exception.Message)"
    }
}
else {
    Write-Host "  ? Test skipped (no test user)" -ForegroundColor Yellow
}

# Test 5: Disable User
Write-Host "`nTest 5: Disable User"
if ($script:TestUserId) {
    try {
        $headers = @{
            Authorization = "Bearer $script:AdminToken"
        }

        $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/provisioning/$script:TestUserId/disable" `
            -Method Put `
            -Headers $headers

        if ($response.isDisabled -eq $true) {
            Test-Pass "User disabled successfully"
        }
        else {
            Test-Fail "User disable returned unexpected value: isDisabled = $($response.isDisabled)"
        }
    }
    catch {
        Test-Fail "Failed to disable user: $($_.Exception.Message)"
    }
}
else {
    Write-Host "  ? Test skipped (no test user)" -ForegroundColor Yellow
}

# Test 6: Verify Disabled User Cannot Login
Write-Host "`nTest 6: Verify Disabled User Cannot Login"
try {
    $body = @{
        username = "provisiontest@example.com"
        password = "Test123!"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    Test-Fail "Disabled user was able to login"
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 403) {
        Test-Pass "Disabled user correctly blocked from login (403)"
    }
    else {
        Test-Fail "Disabled user login blocked with unexpected code: $statusCode"
    }
}

# Test 7: Enable User
Write-Host "`nTest 7: Enable User"
if ($script:TestUserId) {
    try {
        $headers = @{
            Authorization = "Bearer $script:AdminToken"
        }

        $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/provisioning/$script:TestUserId/enable" `
            -Method Put `
            -Headers $headers

        if ($response.isDisabled -eq $false) {
            Test-Pass "User enabled successfully"
        }
        else {
            Test-Fail "User enable returned unexpected value: isDisabled = $($response.isDisabled)"
        }
    }
    catch {
        Test-Fail "Failed to enable user: $($_.Exception.Message)"
    }
}
else {
    Write-Host "  ? Test skipped (no test user)" -ForegroundColor Yellow
}

# Test 8: Verify Enabled User Can Login
Write-Host "`nTest 8: Verify Enabled User Can Login"
try {
    $body = @{
        username = "provisiontest@example.com"
        password = "Test123!"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    if ($response.token) {
        Test-Pass "Enabled user can login successfully"
    }
    else {
        Test-Fail "Enabled user login succeeded but no token"
    }
}
catch {
    Test-Fail "Enabled user cannot login: $($_.Exception.Message)"
}

# Test 9: Duplicate Email Rejected
Write-Host "`nTest 9: Duplicate Email Rejected"
try {
    $headers = @{
        Authorization = "Bearer $script:AdminToken"
    }
    
    $body = @{
        email = "provisiontest@example.com"
        tempPassword = "Test123!"
        roles = @("booker")
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/provisioning" `
        -Method Post `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $body

    Test-Fail "Duplicate email was accepted"
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 409) {
        Test-Pass "Duplicate email correctly rejected (409 Conflict)"
    }
    else {
        Test-Fail "Duplicate email rejected with unexpected code: $statusCode"
    }
}

# Test 10: Pagination
Write-Host "`nTest 10: Pagination Parameters"
try {
    $headers = @{
        Authorization = "Bearer $script:AdminToken"
    }
    
    $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/provisioning?take=2&skip=0" `
        -Method Get `
        -Headers $headers

    if ($response.Count -le 2) {
        Test-Pass "Pagination working (returned $($response.Count) users)"
    }
    else {
        Test-Fail "Pagination not working (returned $($response.Count) users, expected ?2)"
    }
}
catch {
    Test-Fail "Failed to test pagination: $($_.Exception.Message)"
}

# Summary
Write-Host ""
Write-Host "???????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host "User Provisioning API Tests Complete" -ForegroundColor Cyan
Write-Host "Passed: $script:TestsPassed" -ForegroundColor Green
Write-Host "Failed: $script:TestsFailed" -ForegroundColor Red
Write-Host "???????????????????????????????????????????????????????" -ForegroundColor Cyan

if ($script:TestsFailed -eq 0) {
    exit 0
}
else {
    exit 1
}
