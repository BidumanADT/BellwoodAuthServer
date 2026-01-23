# Test Script for GET /api/admin/users Endpoint
# Tests the new user list endpoint with various scenarios

# Configuration
$AuthServerUrl = "https://localhost:5001"
$AdminUser = "alice"
$AdminPass = "password"
$DispatcherUser = "diana"
$DispatcherPass = "password"

# Helper functions
function Print-Test {
    param([string]$Description)
    Write-Host "`n???????????????????????????????????????????????????????" -ForegroundColor Yellow
    Write-Host "TEST: $Description" -ForegroundColor Yellow
    Write-Host "???????????????????????????????????????????????????????" -ForegroundColor Yellow
}

function Print-Pass {
    param([string]$Message)
    Write-Host "? PASS: $Message" -ForegroundColor Green
}

function Print-Fail {
    param([string]$Message)
    Write-Host "? FAIL: $Message" -ForegroundColor Red
}

function Print-Info {
    param([string]$Message)
    Write-Host "? INFO: $Message" -ForegroundColor Cyan
}

# Suppress SSL validation warnings
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

Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host "?      GET /api/admin/users - Endpoint Test Suite           ?" -ForegroundColor Cyan
Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host ""
Write-Host "Server: $AuthServerUrl"
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

# ============================================================================
# Get Admin Token
# ============================================================================
Print-Test "Login as Admin"

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
    Print-Pass "Admin login successful"
}
catch {
    Print-Fail "Login failed: $($_.Exception.Message)"
    exit 1
}

# ============================================================================
# TEST 1: Get All Users (No Filter)
# ============================================================================
Print-Test "Get All Users (No Filter)"

try {
    $headers = @{
        Authorization = "Bearer $script:AdminToken"
    }
    
    $users = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users" `
        -Method Get `
        -Headers $headers
    
    Print-Pass "Retrieved all users successfully"
    Print-Info "Total users: $($users.Count)"
    
    # Display users
    foreach ($user in $users) {
        Write-Host "  - $($user.username) ($($user.role)) - $($user.email)" -ForegroundColor Gray
    }
    
    # Verify expected users exist
    $expectedUsers = @("alice", "bob", "chris", "charlie", "diana")
    $foundUsers = $users | Select-Object -ExpandProperty username
    
    foreach ($expected in $expectedUsers) {
        if ($foundUsers -contains $expected) {
            Print-Info "? Found expected user: $expected"
        }
        else {
            Print-Fail "? Missing expected user: $expected"
        }
    }
}
catch {
    Print-Fail "Request failed: $($_.Exception.Message)"
}

# ============================================================================
# TEST 2: Filter by Role - Admin
# ============================================================================
Print-Test "Filter by Role: admin"

try {
    $headers = @{
        Authorization = "Bearer $script:AdminToken"
    }
    
    $users = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users?role=admin" `
        -Method Get `
        -Headers $headers
    
    Print-Pass "Retrieved admin users successfully"
    Print-Info "Admin users: $($users.Count)"
    
    foreach ($user in $users) {
        Write-Host "  - $($user.username) - $($user.email)" -ForegroundColor Gray
        
        if ($user.role -ne "admin") {
            Print-Fail "User $($user.username) has role $($user.role), expected admin"
        }
    }
}
catch {
    Print-Fail "Request failed: $($_.Exception.Message)"
}

# ============================================================================
# TEST 3: Filter by Role - Dispatcher
# ============================================================================
Print-Test "Filter by Role: dispatcher"

try {
    $headers = @{
        Authorization = "Bearer $script:AdminToken"
    }
    
    $users = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users?role=dispatcher" `
        -Method Get `
        -Headers $headers
    
    Print-Pass "Retrieved dispatcher users successfully"
    Print-Info "Dispatcher users: $($users.Count)"
    
    foreach ($user in $users) {
        Write-Host "  - $($user.username) - $($user.email)" -ForegroundColor Gray
        
        if ($user.role -ne "dispatcher") {
            Print-Fail "User $($user.username) has role $($user.role), expected dispatcher"
        }
    }
    
    # Verify diana is in the list
    $diana = $users | Where-Object { $_.username -eq "diana" }
    if ($diana) {
        Print-Info "? Diana found with dispatcher role"
        Print-Info "  Email: $($diana.email)"
        Print-Info "  Active: $($diana.isActive)"
    }
    else {
        Print-Fail "Diana not found in dispatcher list"
    }
}
catch {
    Print-Fail "Request failed: $($_.Exception.Message)"
}

# ============================================================================
# TEST 4: Filter by Role - Driver
# ============================================================================
Print-Test "Filter by Role: driver"

try {
    $headers = @{
        Authorization = "Bearer $script:AdminToken"
    }
    
    $users = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users?role=driver" `
        -Method Get `
        -Headers $headers
    
    Print-Pass "Retrieved driver users successfully"
    Print-Info "Driver users: $($users.Count)"
    
    foreach ($user in $users) {
        Write-Host "  - $($user.username)" -ForegroundColor Gray
    }
}
catch {
    Print-Fail "Request failed: $($_.Exception.Message)"
}

# ============================================================================
# TEST 5: Dispatcher Cannot Access Endpoint
# ============================================================================
Print-Test "Dispatcher Cannot Access Endpoint (Authorization Test)"

try {
    # Login as dispatcher
    $body = @{
        username = $DispatcherUser
        password = $DispatcherPass
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    $dispatcherToken = $response.token
    
    # Try to access endpoint
    $headers = @{
        Authorization = "Bearer $dispatcherToken"
    }
    
    $users = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users" `
        -Method Get `
        -Headers $headers
    
    Print-Fail "Dispatcher was able to access admin endpoint (should be 403)"
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 403 -or $statusCode -eq 401) {
        Print-Pass "Dispatcher correctly denied access ($statusCode)"
    }
    else {
        Print-Fail "Expected 403 or 401, got $statusCode"
    }
}

# ============================================================================
# TEST 6: Verify Response Format
# ============================================================================
Print-Test "Verify Response Format Matches Specification"

try {
    $headers = @{
        Authorization = "Bearer $script:AdminToken"
    }
    
    $users = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users" `
        -Method Get `
        -Headers $headers
    
    if ($users.Count -gt 0) {
        $user = $users[0]
        
        $requiredFields = @("username", "userId", "email", "role", "isActive", "createdAt")
        $missingFields = @()
        
        foreach ($field in $requiredFields) {
            if (-not ($user.PSObject.Properties.Name -contains $field)) {
                $missingFields += $field
            }
        }
        
        if ($missingFields.Count -eq 0) {
            Print-Pass "All required fields present in response"
            Print-Info "Sample user object:"
            Write-Host ($user | ConvertTo-Json -Depth 1) -ForegroundColor Gray
        }
        else {
            Print-Fail "Missing fields: $($missingFields -join ', ')"
        }
    }
    else {
        Print-Fail "No users returned to verify format"
    }
}
catch {
    Print-Fail "Request failed: $($_.Exception.Message)"
}

# ============================================================================
# Summary
# ============================================================================
Write-Host ""
Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host "?                    TEST COMPLETE                           ?" -ForegroundColor Cyan
Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host ""
Write-Host "Endpoint: GET /api/admin/users" -ForegroundColor Green
Write-Host "Status: Ready for Admin Portal integration" -ForegroundColor Green
Write-Host ""
