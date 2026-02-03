# Clean Up Test Users
# Removes test users created by test scripts to allow clean re-runs

param(
    [string]$AuthServerUrl = "https://localhost:5001",
    [switch]$DeleteAll,
    [switch]$WhatIf
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
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls

Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host "?           Test User Cleanup Utility                       ?" -ForegroundColor Cyan
Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host ""

# Test users created by test scripts
$testUsers = @(
    "lockouttest@example.com"
    "roletest1@example.com"
    "roletest2@example.com"
    "roletest3@example.com"
    "roletest4@example.com"
    "provisiontest@example.com"
)

# Get admin token
Write-Host "Getting admin token..." -ForegroundColor Yellow
try {
    $body = @{
        username = "alice"
        password = "password"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    $adminToken = $response.token
    Write-Host "? Admin token obtained" -ForegroundColor Green
}
catch {
    Write-Host "? Failed to get admin token: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Get all users
Write-Host "`nFetching user list..." -ForegroundColor Yellow
try {
    $headers = @{
        Authorization = "Bearer $adminToken"
    }
    
    $allUsers = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/provisioning?take=100" `
        -Method Get `
        -Headers $headers
    
    Write-Host "? Retrieved $($allUsers.Count) users" -ForegroundColor Green
}
catch {
    Write-Host "? Failed to get user list: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Find test users
Write-Host "`nSearching for test users..." -ForegroundColor Yellow
$foundTestUsers = @()

foreach ($email in $testUsers) {
    $user = $allUsers | Where-Object { $_.email -eq $email }
    if ($user) {
        $foundTestUsers += $user
        $status = if ($user.isDisabled) { "DISABLED" } else { "ACTIVE" }
        Write-Host "  Found: $($user.email) ($status)" -ForegroundColor Cyan
    }
}

if ($foundTestUsers.Count -eq 0) {
    Write-Host "  No test users found - database is clean!" -ForegroundColor Green
    exit 0
}

Write-Host "`nFound $($foundTestUsers.Count) test user(s)" -ForegroundColor Yellow

# Enable all test users (so they can be used in next test run)
Write-Host "`nEnabling test users for reuse..." -ForegroundColor Yellow

$enabled = 0
$failed = 0

foreach ($user in $foundTestUsers) {
    if ($user.isDisabled) {
        if ($WhatIf) {
            Write-Host "  Would enable: $($user.email)" -ForegroundColor Gray
        }
        else {
            try {
                Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/provisioning/$($user.userId)/enable" `
                    -Method Put `
                    -Headers $headers | Out-Null
                
                Write-Host "  ? Enabled: $($user.email)" -ForegroundColor Green
                $enabled++
            }
            catch {
                Write-Host "  ? Failed to enable $($user.email): $($_.Exception.Message)" -ForegroundColor Red
                $failed++
            }
        }
    }
    else {
        Write-Host "  - Already enabled: $($user.email)" -ForegroundColor Gray
    }
}

# Summary
Write-Host ""
Write-Host "???????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host " Summary" -ForegroundColor Cyan
Write-Host "???????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test users found: $($foundTestUsers.Count)"
if (-not $WhatIf) {
    Write-Host "Users enabled:    " -NoNewline
    Write-Host "$enabled" -ForegroundColor Green
    Write-Host "Failed:           " -NoNewline
    Write-Host "$failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Gray" })
}

Write-Host ""
Write-Host "Test users are now ready for reuse in next test run!" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Test users are NOT deleted - they're just enabled." -ForegroundColor Yellow
Write-Host "This allows tests to reuse them instead of creating duplicates." -ForegroundColor Yellow
Write-Host ""

if ($failed -gt 0) {
    exit 1
}
else {
    exit 0
}
