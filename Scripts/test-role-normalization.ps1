# AuthServer - Role Normalization Tests
# PowerShell 5.1 Compatible
# Tests role case normalization to prevent duplicates

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

Write-Host "Role Normalization Tests" -ForegroundColor Cyan
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

# Test 1: Mixed Case Roles Normalized
Write-Host "`nTest 1: Mixed Case Roles Normalized to Lowercase"
try {
    $headers = @{
        Authorization = "Bearer $script:AdminToken"
    }
    
    $body = @{
        email = "roletest1@example.com"
        tempPassword = "Test123!"
        roles = @("Admin", "DISPATCHER")
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/provisioning" `
        -Method Post `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $body

    $allLowercase = $true
    foreach ($role in $response.roles) {
        if ($role -cne $role.ToLower()) {
            $allLowercase = $false
            break
        }
    }

    if ($allLowercase) {
        Test-Pass "All roles normalized to lowercase: $($response.roles -join ', ')"
    }
    else {
        Test-Fail "Roles not normalized: $($response.roles -join ', ')"
    }
    
    $script:TestUser1Id = $response.userId
}
catch {
    Test-Fail "Failed to create user with mixed case roles: $($_.Exception.Message)"
}

# Test 2: Update Roles with Mixed Case
Write-Host "`nTest 2: Update Roles with Mixed Case"
if ($script:TestUser1Id) {
    try {
        $headers = @{
            Authorization = "Bearer $script:AdminToken"
        }
        
        $body = @{
            roles = @("BOOKER")
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/provisioning/$script:TestUser1Id/roles" `
            -Method Put `
            -Headers $headers `
            -ContentType "application/json" `
            -Body $body

        if ($response.roles -contains "booker" -and -not ($response.roles -contains "BOOKER")) {
            Test-Pass "Updated role normalized to lowercase: $($response.roles -join ', ')"
        }
        else {
            Test-Fail "Updated role not normalized: $($response.roles -join ', ')"
        }
    }
    catch {
        Test-Fail "Failed to update roles: $($_.Exception.Message)"
    }
}
else {
    Write-Host "  ? Test skipped (no test user)" -ForegroundColor Yellow
}

# Test 3: All Uppercase Roles
Write-Host "`nTest 3: All Uppercase Roles Normalized"
try {
    $headers = @{
        Authorization = "Bearer $script:AdminToken"
    }
    
    $body = @{
        email = "roletest2@example.com"
        tempPassword = "Test123!"
        roles = @("DRIVER")
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/provisioning" `
        -Method Post `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $body

    if ($response.roles -contains "driver" -and -not ($response.roles -contains "DRIVER")) {
        Test-Pass "Uppercase role normalized to lowercase: $($response.roles -join ', ')"
    }
    else {
        Test-Fail "Uppercase role not normalized: $($response.roles -join ', ')"
    }
    
    $script:TestUser2Id = $response.userId
}
catch {
    Test-Fail "Failed to create user with uppercase role: $($_.Exception.Message)"
}

# Test 4: Multiple Mixed Case Roles
Write-Host "`nTest 4: Multiple Mixed Case Roles"
try {
    $headers = @{
        Authorization = "Bearer $script:AdminToken"
    }
    
    $body = @{
        email = "roletest3@example.com"
        tempPassword = "Test123!"
        roles = @("Admin", "dispatcher", "BOOKER")
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/provisioning" `
        -Method Post `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $body

    $expectedRoles = @("admin", "dispatcher", "booker")
    $allCorrect = $true
    
    foreach ($expectedRole in $expectedRoles) {
        if (-not ($response.roles -contains $expectedRole)) {
            $allCorrect = $false
            break
        }
    }
    
    # Check no uppercase versions
    foreach ($role in $response.roles) {
        if ($role -cne $role.ToLower()) {
            $allCorrect = $false
            break
        }
    }

    if ($allCorrect) {
        Test-Pass "Multiple roles all normalized to lowercase"
    }
    else {
        Test-Fail "Some roles not normalized correctly: $($response.roles -join ', ')"
    }
}
catch {
    Test-Fail "Failed to create user with multiple mixed roles: $($_.Exception.Message)"
}

# Test 5: Role Validation Still Works
Write-Host "`nTest 5: Invalid Role Still Rejected (Case Insensitive)"
try {
    $headers = @{
        Authorization = "Bearer $script:AdminToken"
    }
    
    $body = @{
        email = "roletest4@example.com"
        tempPassword = "Test123!"
        roles = @("INVALIDROLE")
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/provisioning" `
        -Method Post `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $body

    Test-Fail "Invalid role was accepted"
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 400) {
        Test-Pass "Invalid role correctly rejected (400)"
    }
    else {
        Test-Fail "Invalid role rejected with unexpected code: $statusCode"
    }
}

# Summary
Write-Host ""
Write-Host "???????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host "Role Normalization Tests Complete" -ForegroundColor Cyan
Write-Host "Passed: $script:TestsPassed" -ForegroundColor Green
Write-Host "Failed: $script:TestsFailed" -ForegroundColor Red
Write-Host "???????????????????????????????????????????????????????" -ForegroundColor Cyan

if ($script:TestsFailed -eq 0) {
    exit 0
}
else {
    exit 1
}
