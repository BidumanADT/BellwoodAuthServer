# Quick API Response Test
# Verify that Username field is now returned

param(
    [string]$AuthServerUrl = "https://localhost:5001"
)

# Suppress SSL warnings
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

Write-Host "Testing API Response Structure..." -ForegroundColor Cyan
Write-Host ""

# Get admin token
Write-Host "1. Getting admin token..." -ForegroundColor Yellow
$body = @{
    username = "alice"
    password = "password"
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod -Uri "$AuthServerUrl/login" `
    -Method Post `
    -ContentType "application/json" `
    -Body $body

$token = $loginResponse.token
Write-Host "   ? Token obtained" -ForegroundColor Green

# Get users list
Write-Host "`n2. Fetching user list..." -ForegroundColor Yellow
$headers = @{
    Authorization = "Bearer $token"
}

$users = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users?take=5" `
    -Method Get `
    -Headers $headers

Write-Host "   ? Retrieved $($users.Count) users" -ForegroundColor Green

# Check first user structure
Write-Host "`n3. Checking response structure..." -ForegroundColor Yellow
$firstUser = $users[0]

$fields = @{
    "userId" = $firstUser.userId
    "username" = $firstUser.username
    "email" = $firstUser.email
    "roles" = $firstUser.roles
    "isDisabled" = $firstUser.isDisabled
}

Write-Host ""
Write-Host "   Sample User Response:" -ForegroundColor Cyan
foreach ($field in $fields.Keys) {
    $value = $fields[$field]
    if ($value) {
        if ($value -is [Array]) {
            Write-Host "     ? $field : [$($value -join ', ')]" -ForegroundColor Green
        }
        else {
            Write-Host "     ? $field : $value" -ForegroundColor Green
        }
    }
    else {
        Write-Host "     ? $field : (missing or null)" -ForegroundColor Red
    }
}

# Verify AdminPortal compatibility
Write-Host "`n4. AdminPortal Compatibility Check..." -ForegroundColor Yellow

$compatible = $true
$issues = @()

if (-not $firstUser.username) {
    $compatible = $false
    $issues += "Missing 'username' field"
}

if (-not $firstUser.roles) {
    $compatible = $false
    $issues += "Missing 'roles' field"
}

if ($firstUser.roles -and $firstUser.roles.Count -eq 0) {
    Write-Host "   ? User has no roles assigned" -ForegroundColor Yellow
}

if ($compatible) {
    Write-Host "   ? Response structure is compatible with AdminPortal" -ForegroundColor Green
}
else {
    Write-Host "   ? Compatibility issues found:" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host "     - $issue" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Test Complete!" -ForegroundColor Cyan
