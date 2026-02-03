# AuthServer Phase 2 - Test Script (PowerShell)
# Tests all Phase 2 functionality: dispatcher role, policies, role assignment
# Run with: .\test-phase2.ps1

# Configuration
$AuthServerUrl = "https://localhost:5001"
$AdminUser = "alice"
$AdminPass = "password"
$DispatcherUser = "diana"
$DispatcherPass = "password"
$TestUser = "bob"

# Test counters
$script:TestsRun = 0
$script:TestsPassed = 0
$script:TestsFailed = 0

# Helper functions
function Print-Test {
    param([int]$Number, [string]$Description)
    Write-Host "`n???????????????????????????????????????????????????????" -ForegroundColor Yellow
    Write-Host "TEST ${Number}: $Description" -ForegroundColor Yellow
    Write-Host "???????????????????????????????????????????????????????" -ForegroundColor Yellow
    $script:TestsRun++
}

function Print-Pass {
    param([string]$Message)
    Write-Host "? PASS: $Message" -ForegroundColor Green
    $script:TestsPassed++
}

function Print-Fail {
    param([string]$Message)
    Write-Host "? FAIL: $Message" -ForegroundColor Red
    $script:TestsFailed++
}

function Print-Info {
    param([string]$Message)
    Write-Host "? INFO: $Message" -ForegroundColor Cyan
}

function Decode-JwtPayload {
    param([string]$Token)
    $parts = $Token.Split('.')
    if ($parts.Length -lt 2) { return $null }
    
    $payload = $parts[1]
    # Add padding if needed
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

# Suppress SSL validation warnings for localhost testing
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
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls

Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host "?         AuthServer Phase 2 - Functional Tests             ?" -ForegroundColor Cyan
Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host ""
Write-Host "Server: $AuthServerUrl"
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

# ============================================================================
# TEST 1: Dispatcher Role - Login
# ============================================================================
Print-Test -Number 1 -Description "Dispatcher Login"

try {
    $body = @{
        username = $DispatcherUser
        password = $DispatcherPass
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    $script:DispatcherToken = $response.token
    $payload = Decode-JwtPayload -Token $script:DispatcherToken
    
    if ($payload.role -eq "dispatcher") {
        Print-Pass "Dispatcher login successful, role claim is 'dispatcher'"
        Print-Info "Email claim: $($payload.email)"
    }
    else {
        Print-Fail "Expected role 'dispatcher', got '$($payload.role)'"
    }
}
catch {
    Print-Fail "Login failed: $($_.Exception.Message)"
}

# ============================================================================
# TEST 2: Admin Login
# ============================================================================
Print-Test -Number 2 -Description "Admin Login"

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
    $payload = Decode-JwtPayload -Token $script:AdminToken
    
    if ($payload.role -eq "admin") {
        Print-Pass "Admin login successful, role claim is 'admin'"
    }
    else {
        Print-Fail "Expected role 'admin', got '$($payload.role)'"
    }
}
catch {
    Print-Fail "Login failed: $($_.Exception.Message)"
}

# ============================================================================
# TEST 3: Dispatcher Cannot Access Admin Endpoints
# ============================================================================
Print-Test -Number 3 -Description "Dispatcher Denied Admin Access (AdminOnly Policy)"

try {
    $headers = @{
        Authorization = "Bearer $script:DispatcherToken"
    }
    
    $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users/drivers" `
        -Method Get `
        -Headers $headers
    
    Print-Fail "Expected 403, but request succeeded"
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
# TEST 4: Admin Can Access Admin Endpoints
# ============================================================================
Print-Test -Number 4 -Description "Admin Can Access Admin Endpoints"

$maxRetries = 3
$retryDelay = 2
$success = $false

for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
    try {
        if ($attempt -gt 1) {
            Print-Info "Retry attempt $attempt of $maxRetries..."
        }
        
        $headers = @{
            Authorization = "Bearer $script:AdminToken"
        }
        
        # Reset connection by using WebRequest instead of RestMethod on first attempt
        if ($attempt -eq 1) {
            try {
                $request = [System.Net.HttpWebRequest]::Create("$AuthServerUrl/api/admin/users/drivers")
                $request.Method = "GET"
                $request.Headers.Add("Authorization", "Bearer $script:AdminToken")
                $request.KeepAlive = $false  # Don't reuse connection
                $request.Timeout = 30000
                
                $response = $request.GetResponse()
                $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
                $jsonResponse = $reader.ReadToEnd()
                $reader.Close()
                $response.Close()
                
                $data = $jsonResponse | ConvertFrom-Json
                
                Print-Pass "Admin can access admin endpoints (200 OK)"
                Print-Info "Found $($data.Count) driver users"
                $success = $true
                break
            }
            catch {
                # Fall through to retry with RestMethod
                Print-Info "WebRequest attempt failed, trying RestMethod..."
            }
        }
        
        # Use RestMethod (simpler, may work after WebRequest clears connection)
        $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users/drivers" `
            -Method Get `
            -Headers $headers `
            -TimeoutSec 30
        
        Print-Pass "Admin can access admin endpoints (200 OK)"
        Print-Info "Found $($response.Count) driver users"
        $success = $true
        break
    }
    catch {
        $errorMsg = $_.Exception.Message
        $innerMsg = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { "None" }
        
        if ($attempt -lt $maxRetries) {
            Print-Info "Attempt $attempt failed: $errorMsg"
            if ($innerMsg -ne "None") {
                Print-Info "Inner exception: $innerMsg"
            }
            Print-Info "Waiting $retryDelay seconds before retry..."
            Start-Sleep -Seconds $retryDelay
        }
        else {
            Print-Fail "Request failed after $maxRetries attempts"
            Print-Info "Last error: $errorMsg"
            if ($innerMsg -ne "None") {
                Print-Info "Inner exception: $innerMsg"
            }
        }
    }
}

# ============================================================================
# TEST 5: Role Assignment - Change User to Dispatcher
# ============================================================================
Print-Test -Number 5 -Description "Role Assignment - Promote User to Dispatcher"

try {
    $headers = @{
        Authorization = "Bearer $script:AdminToken"
    }
    
    $body = @{
        role = "dispatcher"
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users/$TestUser/role" `
        -Method Put `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $body
    
    if ($response.newRole -eq "dispatcher") {
        Print-Pass "Successfully changed $TestUser to dispatcher"
        Print-Info "Previous roles: $($response.previousRoles -join ', ')"
        Print-Info "New role: $($response.newRole)"
    }
    else {
        Print-Fail "Expected new role 'dispatcher', got '$($response.newRole)'"
    }
}
catch {
    Print-Fail "Role assignment failed: $($_.Exception.Message)"
}

# ============================================================================
# TEST 6: Verify User Has New Role
# ============================================================================
Print-Test -Number 6 -Description "Verify User Has New Role (Re-login)"

try {
    $body = @{
        username = $TestUser
        password = $AdminPass
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    $script:BobToken = $response.token
    $payload = Decode-JwtPayload -Token $script:BobToken
    
    if ($payload.role -eq "dispatcher") {
        Print-Pass "$TestUser now has 'dispatcher' role in JWT"
    }
    else {
        Print-Fail "Expected role 'dispatcher', got '$($payload.role)'"
    }
}
catch {
    Print-Fail "Login failed: $($_.Exception.Message)"
}

# ============================================================================
# TEST 7: New Dispatcher Cannot Access Admin Endpoints
# ============================================================================
Print-Test -Number 7 -Description "New Dispatcher Cannot Access Admin Endpoints"

try {
    $headers = @{
        Authorization = "Bearer $script:BobToken"
    }
    
    $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users/drivers" `
        -Method Get `
        -Headers $headers
    
    Print-Fail "Expected 403, but request succeeded"
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 403 -or $statusCode -eq 401) {
        Print-Pass "$TestUser (now dispatcher) correctly denied admin access"
    }
    else {
        Print-Fail "Expected 403 or 401, got $statusCode"
    }
}

# ============================================================================
# TEST 8: Dispatcher Cannot Assign Roles
# ============================================================================
Print-Test -Number 8 -Description "Dispatcher Cannot Assign Roles"

try {
    $headers = @{
        Authorization = "Bearer $script:DispatcherToken"
    }
    
    $body = @{
        role = "admin"
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users/charlie/role" `
        -Method Put `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $body
    
    Print-Fail "Expected 403, but request succeeded"
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 403 -or $statusCode -eq 401) {
        Print-Pass "Dispatcher correctly denied role assignment capability"
    }
    else {
        Print-Fail "Expected 403 or 401, got $statusCode"
    }
}

# ============================================================================
# TEST 9: Role Assignment Validation (Invalid Role)
# ============================================================================
Print-Test -Number 9 -Description "Role Assignment Validation - Invalid Role"

try {
    $headers = @{
        Authorization = "Bearer $script:AdminToken"
    }
    
    $body = @{
        role = "invalidrole"
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users/$TestUser/role" `
        -Method Put `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $body
    
    Print-Fail "Expected 400, but request succeeded"
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 400) {
        Print-Pass "Invalid role correctly rejected (400 Bad Request)"
        # Try to get error message
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd() | ConvertFrom-Json
            Print-Info "Error: $($errorBody.error)"
        }
        catch { }
    }
    else {
        Print-Fail "Expected 400, got $statusCode"
    }
}

# ============================================================================
# TEST 10: Restore Admin Role
# ============================================================================
Print-Test -Number 10 -Description "Restore User to Admin Role"

try {
    $headers = @{
        Authorization = "Bearer $script:AdminToken"
    }
    
    $body = @{
        role = "admin"
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users/$TestUser/role" `
        -Method Put `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $body
    
    if ($response.newRole -eq "admin") {
        Print-Pass "Successfully restored $TestUser to admin role"
    }
    else {
        Print-Fail "Expected new role 'admin', got '$($response.newRole)'"
    }
}
catch {
    Print-Fail "Role restoration failed: $($_.Exception.Message)"
}

# ============================================================================
# TEST 11: User Diagnostic Endpoint
# ============================================================================
Print-Test -Number 11 -Description "User Diagnostic Endpoint - Check Dispatcher Info"

try {
    $response = Invoke-RestMethod -Uri "$AuthServerUrl/dev/user-info/$DispatcherUser" `
        -Method Get
    
    if ($response.username -eq $DispatcherUser -and $response.roles -contains "dispatcher") {
        Print-Pass "Diagnostic endpoint works, dispatcher info correct"
        Print-Info "Roles: $($response.roles -join ', ')"
        Print-Info "Has email: $($response.diagnostics.hasEmail)"
    }
    else {
        Print-Fail "Unexpected diagnostic response"
    }
}
catch {
    Print-Fail "Diagnostic endpoint failed: $($_.Exception.Message)"
}

# ============================================================================
# TEST 12: Health Check
# ============================================================================
Print-Test -Number 12 -Description "Health Check Endpoint"

try {
    $response = Invoke-RestMethod -Uri "$AuthServerUrl/health" -Method Get
    
    if ($response -eq "ok") {
        Print-Pass "Health check endpoint responding correctly"
    }
    else {
        Print-Fail "Unexpected health check response: $response"
    }
}
catch {
    Print-Fail "Health check failed: $($_.Exception.Message)"
}

# ============================================================================
# Summary
# ============================================================================
Write-Host ""
Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host "?                    TEST SUMMARY                            ?" -ForegroundColor Cyan
Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host ""
Write-Host "Tests Run:    $script:TestsRun"
Write-Host "Tests Passed: " -NoNewline
Write-Host "$script:TestsPassed" -ForegroundColor Green
Write-Host "Tests Failed: " -NoNewline
Write-Host "$script:TestsFailed" -ForegroundColor Red
Write-Host ""

if ($script:TestsFailed -eq 0) {
    Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Green
    Write-Host "?           ? ALL TESTS PASSED - PHASE 2 READY!             ?" -ForegroundColor Green
    Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Red
    Write-Host "?             ? SOME TESTS FAILED - SEE ABOVE                ?" -ForegroundColor Red
    Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Red
    exit 1
}
