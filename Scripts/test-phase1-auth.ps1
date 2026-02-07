# Phase 1 - Basic Authentication Tests
# PowerShell 5.1 Compatible

param(
    [string]$AuthServerUrl = "https://localhost:5001"
)

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

function Decode-JwtPayload {
    param([string]$Token)
    $parts = $Token.Split('.')
    if ($parts.Length -lt 2) { return $null }
    
    $payload = $parts[1]
    while ($payload.Length % 4 -ne 0) {
        $payload += "="
    }
    
    try {
        $bytes = [Convert]::FromBase64String($payload)
        $json = [System.Text.Encoding]::UTF8.GetString($bytes)
        return $json | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

Write-Host "Phase 1 - Basic Authentication Tests" -ForegroundColor Cyan
Write-Host ""

# Test 1: Health Check
Write-Host "Test 1: Health Check"
try {
    $response = Invoke-RestMethod -Uri "$AuthServerUrl/health" -Method Get
    if ($response -eq "ok") {
        Test-Pass "Health endpoint responding"
    }
    else {
        Test-Fail "Unexpected health response: $response"
    }
}
catch {
    Test-Fail "Health check failed: $($_.Exception.Message)"
}

# Test 2: Admin Login
Write-Host "`nTest 2: Admin User Login"
try {
    $body = @{
        username = "alice"
        password = "password"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    if ($response.token) {
        $payload = Decode-JwtPayload -Token $response.token
        if ($payload.role -eq "admin") {
            Test-Pass "Admin login successful with correct role"
            $script:AdminToken = $response.token
        }
        else {
            Test-Fail "Admin login succeeded but role is incorrect: $($payload.role)"
        }
    }
    else {
        Test-Fail "Admin login succeeded but no token in response"
    }
}
catch {
    Test-Fail "Admin login failed: $($_.Exception.Message)"
}

# Test 3: Invalid Credentials
Write-Host "`nTest 3: Invalid Credentials Rejected"
try {
    $body = @{
        username = "alice"
        password = "wrongpassword"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    Test-Fail "Invalid credentials were accepted"
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 401) {
        Test-Pass "Invalid credentials correctly rejected (401)"
    }
    else {
        Test-Fail "Invalid credentials rejected with unexpected code: $statusCode"
    }
}

# Test 4: Missing Username
Write-Host "`nTest 4: Missing Username Validation"
try {
    $body = @{
        password = "password"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    Test-Fail "Request with missing username was accepted"
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 400) {
        Test-Pass "Missing username correctly rejected (400)"
    }
    else {
        Test-Fail "Missing username rejected with unexpected code: $statusCode"
    }
}

# Test 5: Token Contains Required Claims
Write-Host "`nTest 5: JWT Token Claims Validation"
if ($script:AdminToken) {
    $payload = Decode-JwtPayload -Token $script:AdminToken
    
    $requiredClaims = @("sub", "uid", "userId", "role")
    $missingClaims = @()
    
    foreach ($claim in $requiredClaims) {
        if (-not ($payload.PSObject.Properties.Name -contains $claim)) {
            $missingClaims += $claim
        }
    }
    
    if ($missingClaims.Count -eq 0) {
        Test-Pass "All required JWT claims present"
    }
    else {
        Test-Fail "Missing claims: $($missingClaims -join ', ')"
    }
}
else {
    Test-Fail "No token available for validation"
}

# Test 6: Alternate Login Endpoint
Write-Host "`nTest 6: Alternate Login Endpoint (/api/auth/login)"
try {
    $body = @{
        username = "alice"
        password = "password"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/auth/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    if ($response.token) {
        Test-Pass "Alternate login endpoint working"
    }
    else {
        Test-Fail "Alternate login endpoint succeeded but no token"
    }
}
catch {
    Test-Fail "Alternate login endpoint failed: $($_.Exception.Message)"
}

# Test 7: Booker User Login
Write-Host "`nTest 7: Booker User Login"
try {
    $body = @{
        username = "chris"
        password = "password"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    if ($response.token) {
        $payload = Decode-JwtPayload -Token $response.token
        if ($payload.role -eq "booker") {
            Test-Pass "Booker login successful with correct role"
        }
        else {
            Test-Fail "Booker login succeeded but role incorrect: $($payload.role)"
        }
    }
    else {
        Test-Fail "Booker login succeeded but no token"
    }
}
catch {
    Test-Fail "Booker login failed: $($_.Exception.Message)"
}

# Test 8: Driver User Login
Write-Host "`nTest 8: Driver User Login"
try {
    $body = @{
        username = "charlie"
        password = "password"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    if ($response.token) {
        $payload = Decode-JwtPayload -Token $response.token
        if ($payload.role -eq "driver") {
            Test-Pass "Driver login successful with correct role"
        }
        else {
            Test-Fail "Driver login succeeded but role incorrect: $($payload.role)"
        }
    }
    else {
        Test-Fail "Driver login succeeded but no token"
    }
}
catch {
    Test-Fail "Driver login failed: $($_.Exception.Message)"
}

# Summary
Write-Host ""
Write-Host "???????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host "Phase 1 Tests Complete" -ForegroundColor Cyan
Write-Host "Passed: $script:TestsPassed" -ForegroundColor Green
Write-Host "Failed: $script:TestsFailed" -ForegroundColor Red
Write-Host "???????????????????????????????????????????????????????" -ForegroundColor Cyan

if ($script:TestsFailed -eq 0) {
    exit 0
}
else {
    exit 1
}
