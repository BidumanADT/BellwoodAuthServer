# Check exact HTTP response casing
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

Write-Host "Checking exact HTTP response (raw bytes)..." -ForegroundColor Cyan
Write-Host ""

# Get token first
$loginBody = '{"username":"alice","password":"password"}'
$loginRequest = [System.Net.HttpWebRequest]::Create("$AuthServerUrl/login")
$loginRequest.Method = "POST"
$loginRequest.ContentType = "application/json"
$loginRequest.KeepAlive = $false

$loginBytes = [System.Text.Encoding]::UTF8.GetBytes($loginBody)
$loginRequest.ContentLength = $loginBytes.Length
$loginStream = $loginRequest.GetRequestStream()
$loginStream.Write($loginBytes, 0, $loginBytes.Length)
$loginStream.Close()

$loginResponse = $loginRequest.GetResponse()
$loginReader = New-Object System.IO.StreamReader($loginResponse.GetResponseStream())
$loginJson = $loginReader.ReadToEnd()
$loginReader.Close()
$loginResponse.Close()

$loginData = $loginJson | ConvertFrom-Json
$token = $loginData.token

Write-Host "Token obtained: $($token.Substring(0, 20))..." -ForegroundColor Green
Write-Host ""

# Now get users with raw response
$usersRequest = [System.Net.HttpWebRequest]::Create("$AuthServerUrl/api/admin/users?take=1")
$usersRequest.Method = "GET"
$usersRequest.Headers.Add("Authorization", "Bearer $token")
$usersRequest.KeepAlive = $false

$usersResponse = $usersRequest.GetResponse()
$usersReader = New-Object System.IO.StreamReader($usersResponse.GetResponseStream())
$usersJson = $usersReader.ReadToEnd()
$usersReader.Close()
$usersResponse.Close()

Write-Host "Raw HTTP Response Body:" -ForegroundColor Yellow
Write-Host $usersJson
Write-Host ""

# Check exact field names
if ($usersJson -match '"roles"') {
    Write-Host "? Found 'roles' with lowercase 'r'" -ForegroundColor Green
}
elseif ($usersJson -match '"Roles"') {
    Write-Host "? Found 'Roles' with capital 'R' - JsonPropertyName not working!" -ForegroundColor Red
}
else {
    Write-Host "? 'roles' field not found at all!" -ForegroundColor Red
}

if ($usersJson -match '"username"') {
    Write-Host "? Found 'username' with lowercase 'u'" -ForegroundColor Green
}
elseif ($usersJson -match '"Username"') {
    Write-Host "? Found 'Username' with capital 'U'" -ForegroundColor Yellow
}
