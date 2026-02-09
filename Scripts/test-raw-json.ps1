# Test raw JSON response
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

Write-Host "Getting raw JSON response from API..." -ForegroundColor Cyan
Write-Host ""

# Get admin token
$body = @{
    username = "alice"
    password = "password"
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod -Uri "$AuthServerUrl/login" `
    -Method Post `
    -ContentType "application/json" `
    -Body $body

$token = $loginResponse.token

# Get users list
$headers = @{
    Authorization = "Bearer $token"
}

$users = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users?take=3" `
    -Method Get `
    -Headers $headers

Write-Host "Raw JSON Response:" -ForegroundColor Yellow
Write-Host ""
$users | ConvertTo-Json -Depth 5
Write-Host ""

Write-Host "First User Properties:" -ForegroundColor Yellow
$firstUser = $users[0]
Write-Host "  userId: $($firstUser.userId)"
Write-Host "  username: $($firstUser.username)"
Write-Host "  email: $($firstUser.email)"
Write-Host "  roles: [$($firstUser.roles -join ', ')]"
Write-Host "  roles type: $($firstUser.roles.GetType().Name)"
Write-Host "  roles count: $($firstUser.roles.Count)"
Write-Host "  isDisabled: $($firstUser.isDisabled)"
Write-Host ""

# Check if roles is actually populated
if ($firstUser.roles -and $firstUser.roles.Count -gt 0) {
    Write-Host "? Roles ARE being returned by the API" -ForegroundColor Green
    Write-Host "  Issue is likely in AdminPortal's JavaScript code" -ForegroundColor Yellow
}
else {
    Write-Host "? Roles are NOT being returned by the API" -ForegroundColor Red
    Write-Host "  Issue is in the AuthServer" -ForegroundColor Yellow
}
