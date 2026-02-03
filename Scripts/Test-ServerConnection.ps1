# AuthServer - Connection Diagnostic Tool
# Helps troubleshoot connection issues to AuthServer

param(
    [string]$AuthServerUrl = "https://localhost:5001"
)

Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host "?       AuthServer Connection Diagnostics                   ?" -ForegroundColor Cyan
Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target URL: $AuthServerUrl" -ForegroundColor Yellow
Write-Host ""

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

# Test 1: Basic Network Connectivity
Write-Host "Test 1: Network Connectivity" -ForegroundColor Yellow
$uri = [System.Uri]$AuthServerUrl
$hostname = $uri.Host
$port = $uri.Port

try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $tcpClient.Connect($hostname, $port)
    $tcpClient.Close()
    Write-Host "  ? Can connect to ${hostname}:${port}" -ForegroundColor Green
}
catch {
    Write-Host "  ? Cannot connect to ${hostname}:${port}" -ForegroundColor Red
    Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "    Possible causes:" -ForegroundColor Yellow
    Write-Host "    - Server is not running" -ForegroundColor Gray
    Write-Host "    - Firewall blocking connection" -ForegroundColor Gray
    Write-Host "    - Wrong URL or port" -ForegroundColor Gray
}

# Test 2: SSL Certificate
Write-Host "`nTest 2: SSL Certificate" -ForegroundColor Yellow
try {
    $request = [System.Net.WebRequest]::Create("$AuthServerUrl/health")
    $request.Method = "GET"
    $request.Timeout = 5000
    
    $response = $request.GetResponse()
    Write-Host "  ? SSL connection successful" -ForegroundColor Green
    $response.Close()
}
catch {
    Write-Host "  ? SSL connection issue" -ForegroundColor Yellow
    Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Gray
    Write-Host "    (This is normal for self-signed certificates)" -ForegroundColor Gray
}

# Test 3: Health Endpoint
Write-Host "`nTest 3: Health Endpoint (/health)" -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$AuthServerUrl/health" `
        -Method Get `
        -TimeoutSec 10 `
        -UseBasicParsing
    
    Write-Host "  ? Health endpoint responding" -ForegroundColor Green
    Write-Host "    Status Code: $($response.StatusCode)" -ForegroundColor Gray
    Write-Host "    Response: $($response.Content)" -ForegroundColor Gray
}
catch {
    Write-Host "  ? Health endpoint failed" -ForegroundColor Red
    Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Gray
    
    if ($_.Exception.Response) {
        Write-Host "    Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Gray
    }
}

# Test 4: Invoke-RestMethod (what tests use)
Write-Host "`nTest 4: Invoke-RestMethod Test" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$AuthServerUrl/health" `
        -Method Get `
        -TimeoutSec 10
    
    if ($response -eq "ok") {
        Write-Host "  ? Invoke-RestMethod working correctly" -ForegroundColor Green
        Write-Host "    Response: $response" -ForegroundColor Gray
    }
    else {
        Write-Host "  ? Unexpected response" -ForegroundColor Yellow
        Write-Host "    Response: $response" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  ? Invoke-RestMethod failed" -ForegroundColor Red
    Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Gray
    Write-Host "    Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Gray
    
    if ($_.Exception.InnerException) {
        Write-Host "    Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Gray
    }
}

# Test 5: Alternate Health Endpoint
Write-Host "`nTest 5: Alternate Health Endpoint (/healthz)" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$AuthServerUrl/healthz" `
        -Method Get `
        -TimeoutSec 10
    
    if ($response -eq "ok") {
        Write-Host "  ? Alternate health endpoint working" -ForegroundColor Green
    }
}
catch {
    Write-Host "  ? Alternate health endpoint failed" -ForegroundColor Red
    Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Gray
}

# Test 6: Login Endpoint Accessibility
Write-Host "`nTest 6: Login Endpoint Accessibility" -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$AuthServerUrl/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body '{"username":"test","password":"test"}' `
        -TimeoutSec 10 `
        -UseBasicParsing
    
    Write-Host "  ? Login endpoint accessible" -ForegroundColor Green
    Write-Host "    (Response code: $($response.StatusCode))" -ForegroundColor Gray
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 401 -or $statusCode -eq 400) {
        Write-Host "  ? Login endpoint accessible (expected auth failure)" -ForegroundColor Green
        Write-Host "    Status: $statusCode" -ForegroundColor Gray
    }
    else {
        Write-Host "  ? Login endpoint issue" -ForegroundColor Yellow
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Gray
    }
}

# Summary
Write-Host ""
Write-Host "???????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host " Diagnostic Summary" -ForegroundColor Cyan
Write-Host "???????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host ""
Write-Host "If all tests passed, the server is working correctly." -ForegroundColor Green
Write-Host "If tests failed, review the errors above." -ForegroundColor Yellow
Write-Host ""
Write-Host "Common solutions:" -ForegroundColor Yellow
Write-Host "  1. Ensure AuthServer is running (dotnet run)" -ForegroundColor Gray
Write-Host "  2. Wait a few seconds after starting server" -ForegroundColor Gray
Write-Host "  3. Check server console for errors" -ForegroundColor Gray
Write-Host "  4. Try using -StartupDelay parameter:" -ForegroundColor Gray
Write-Host "     .\Scripts\Run-AllTests.ps1 -StartupDelay 5" -ForegroundColor Gray
Write-Host ""
