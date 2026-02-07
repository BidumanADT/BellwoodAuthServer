# AuthServer - Master Test Suite Runner
# PowerShell 5.1 Compatible
# Runs all test scripts in sequence and generates comprehensive report

param(
    [string]$AuthServerUrl = "https://localhost:5001",
    [switch]$SkipPhase1,
    [switch]$SkipPhase2,
    [switch]$SkipLockout,
    [switch]$SkipRoles,
    [switch]$SkipProvisioning,
    [switch]$StopOnError,
    [int]$StartupDelay = 0,
    [switch]$Verbose
)

# Suppress SSL validation warnings
# Check if type already exists before adding (prevents errors when called from master test runner)
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
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls

# Test results tracking
$script:TotalTests = 0
$script:PassedTests = 0
$script:FailedTests = 0
$script:SkippedTests = 0
$script:TestResults = @()

# Helper functions
function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Cyan
    Write-Host "?  $($Text.PadRight(58))?" -ForegroundColor Cyan
    Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Cyan
    Write-Host ""
}

function Write-TestSuite {
    param([string]$Name)
    Write-Host ""
    Write-Host "???????????????????????????????????????????????????????" -ForegroundColor Yellow
    Write-Host " TEST SUITE: $Name" -ForegroundColor Yellow
    Write-Host "???????????????????????????????????????????????????????" -ForegroundColor Yellow
}

function Add-TestResult {
    param(
        [string]$Suite,
        [string]$Test,
        [string]$Status,
        [string]$Message = ""
    )
    
    $script:TestResults += [PSCustomObject]@{
        Suite = $Suite
        Test = $Test
        Status = $Status
        Message = $Message
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $script:TotalTests++
    
    switch ($Status) {
        "PASS" { 
            $script:PassedTests++
            Write-Host "  ? $Test" -ForegroundColor Green
            if ($Message) { Write-Host "    $Message" -ForegroundColor Gray }
        }
        "FAIL" { 
            $script:FailedTests++
            Write-Host "  ? $Test" -ForegroundColor Red
            if ($Message) { Write-Host "    $Message" -ForegroundColor Gray }
        }
        "SKIP" { 
            $script:SkippedTests++
            Write-Host "  ? $Test (SKIPPED)" -ForegroundColor Yellow
            if ($Message) { Write-Host "    $Message" -ForegroundColor Gray }
        }
    }
}

function Initialize-ServerConnection {
    param([string]$Url)
    
    Write-Host "Initializing server connection..." -ForegroundColor Yellow
    
    # Test 1: Basic Network Connectivity
    $uri = [System.Uri]$Url
    $hostname = $uri.Host
    $port = $uri.Port

    try {
        Write-Host "  Testing network connectivity to ${hostname}:${port}..." -ForegroundColor Gray
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($hostname, $port)
        $tcpClient.Close()
        Write-Host "  ? Network connection established" -ForegroundColor Green
    }
    catch {
        Write-Host "  ? Cannot connect to ${hostname}:${port}" -ForegroundColor Red
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Gray
        return $false
    }

    # Test 2: HTTP Request to initialize connection
    try {
        Write-Host "  Initializing HTTP connection..." -ForegroundColor Gray
        $request = [System.Net.WebRequest]::Create("$Url/health")
        $request.Method = "GET"
        $request.Timeout = 10000
        
        $response = $request.GetResponse()
        Write-Host "  ? HTTP connection initialized" -ForegroundColor Green
        $response.Close()
    }
    catch {
        Write-Host "  ? HTTP initialization warning (may be normal for HTTPS)" -ForegroundColor Yellow
    }

    # Test 3: Invoke-WebRequest to warm up
    try {
        Write-Host "  Warming up WebRequest..." -ForegroundColor Gray
        $null = Invoke-WebRequest -Uri "$Url/health" `
            -Method Get `
            -TimeoutSec 10 `
            -UseBasicParsing `
            -ErrorAction SilentlyContinue
        Write-Host "  ? WebRequest warmed up" -ForegroundColor Green
    }
    catch {
        # Ignore errors here
    }

    # Test 4: Invoke-RestMethod final test
    try {
        Write-Host "  Testing RestMethod..." -ForegroundColor Gray
        $response = Invoke-RestMethod -Uri "$Url/health" `
            -Method Get `
            -TimeoutSec 10
        
        if ($response -eq "ok") {
            Write-Host "  ? RestMethod working correctly" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Host "  ? RestMethod test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    return $true
}

function Test-ServerHealth {
    param(
        [int]$MaxRetries = 3,
        [int]$RetryDelay = 2
    )
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            if ($Verbose) {
                Write-Host "  Attempt $i of ${MaxRetries}..." -ForegroundColor Gray
                Write-Host "    Testing: $AuthServerUrl/health" -ForegroundColor Gray
            }
            else {
                Write-Host "  Attempt $i of ${MaxRetries}..." -ForegroundColor Gray
            }
            
            $response = Invoke-RestMethod -Uri "$AuthServerUrl/health" `
                -Method Get `
                -TimeoutSec 10 `
                -ErrorAction Stop
            
            if ($Verbose) {
                Write-Host "    Response: $response" -ForegroundColor Gray
            }
            
            if ($response -eq "ok") {
                return $true
            }
        }
        catch {
            if ($Verbose) {
                Write-Host "    Full Error: $($_.Exception.ToString())" -ForegroundColor Gray
            }
            else {
                Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Gray
            }
            
            if ($i -lt $MaxRetries) {
                Write-Host "    Waiting ${RetryDelay} seconds before retry..." -ForegroundColor Gray
                Start-Sleep -Seconds $RetryDelay
            }
        }
    }
    
    return $false
}

# Start test execution
$startTime = Get-Date

Write-Header "AuthServer Complete Test Suite"

Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Server URL: $AuthServerUrl"
Write-Host "  Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "  PowerShell Version: $($PSVersionTable.PSVersion)"
Write-Host ""

# Initialize connection first (this is the key!)
Write-Host ""
if (-not (Initialize-ServerConnection -Url $AuthServerUrl)) {
    Write-Host ""
    Write-Host "? Server connection initialization failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify server is running:" -ForegroundColor Gray
    Write-Host "     dotnet run" -ForegroundColor Gray
    Write-Host "  2. Check server logs for errors" -ForegroundColor Gray
    Write-Host "  3. Verify URL is correct: $AuthServerUrl" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

# Clean up test data from previous runs
Write-Host ""
Write-Host "Cleaning up test data from previous runs..." -ForegroundColor Yellow
try {
    # Get admin token for cleanup
    $body = @{
        username = "alice"
        password = "password"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$AuthServerUrl/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body

    $cleanupToken = $response.token
    
    $headers = @{
        Authorization = "Bearer $cleanupToken"
    }
    
    # Test users created by test scripts
    $testEmails = @(
        "lockouttest@example.com"
        "roletest1@example.com"
        "roletest2@example.com"
        "roletest3@example.com"
        "roletest4@example.com"
        "provisiontest@example.com"
    )
    
    # Get all users
    $allUsers = Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users?take=100" `
        -Method Get `
        -Headers $headers
    
    $cleaned = 0
    foreach ($email in $testEmails) {
        $user = $allUsers | Where-Object { $_.email -eq $email }
        if ($user) {
            # Enable the user (disabled users can't be cleaned up properly)
            try {
                Invoke-RestMethod -Uri "$AuthServerUrl/api/admin/users/$($user.userId)/enable" `
                    -Method Put `
                    -Headers $headers | Out-Null
                Write-Host "  ? Enabled test user: $email" -ForegroundColor Gray
                $cleaned++
            }
            catch {
                Write-Host "  ? Could not enable $email : $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
    
    if ($cleaned -gt 0) {
        Write-Host "? Cleaned up $cleaned test user(s)" -ForegroundColor Green
    }
    else {
        Write-Host "? No test users needed cleanup" -ForegroundColor Green
    }
}
catch {
    Write-Host "? Could not clean up test data: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  Tests will attempt to reuse existing data" -ForegroundColor Gray
}

# Optional startup delay
if ($StartupDelay -gt 0) {
    Write-Host ""
    Write-Host "Waiting $StartupDelay seconds for server to fully start..." -ForegroundColor Yellow
    Start-Sleep -Seconds $StartupDelay
}

# Pre-flight check
Write-Host ""
Write-Host "Pre-flight check: Verifying server is healthy..." -ForegroundColor Yellow

if (Test-ServerHealth) {
    Write-Host "? Server is running and healthy" -ForegroundColor Green
}
else {
    Write-Host "? Server health check failed after multiple attempts!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify server is running:" -ForegroundColor Gray
    Write-Host "     dotnet run" -ForegroundColor Gray
    Write-Host "  2. Check server logs for errors" -ForegroundColor Gray
    Write-Host "  3. Verify URL is correct: $AuthServerUrl" -ForegroundColor Gray
    Write-Host "  4. Try adding startup delay:" -ForegroundColor Gray
    Write-Host "     .\Scripts\Run-AllTests.ps1 -StartupDelay 5" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Server output should show:" -ForegroundColor Yellow
    Write-Host "  Now listening on: https://localhost:5001" -ForegroundColor Gray
    Write-Host "  Now listening on: http://localhost:5000" -ForegroundColor Gray
    Write-Host "  Application started. Press Ctrl+C to shut down." -ForegroundColor Gray
    Write-Host ""
    exit 1
}

# Allow server startup time
if ($StartupDelay -gt 0) {
    Write-Host "Waiting $StartupDelay seconds to allow server to start..." -ForegroundColor Yellow
    Start-Sleep -Seconds $StartupDelay
}

# Define test suites
$testSuites = @(
    @{
        Name = "Phase 1 - Basic Authentication"
        Script = "test-phase1-auth.ps1"
        Skip = $SkipPhase1
    },
    @{
        Name = "Phase 2 - Role-Based Access Control"
        Script = "test-phase2.ps1"
        Skip = $SkipPhase2
    },
    @{
        Name = "Lockout Enforcement"
        Script = "test-lockout-enforcement.ps1"
        Skip = $SkipLockout
    },
    @{
        Name = "Role Normalization"
        Script = "test-role-normalization.ps1"
        Skip = $SkipRoles
    },
    @{
        Name = "User Provisioning API"
        Script = "test-provisioning-api.ps1"
        Skip = $SkipProvisioning
    }
)

# Run each test suite
foreach ($suite in $testSuites) {
    if ($suite.Skip) {
        Write-TestSuite $suite.Name
        Write-Host "  ? Test suite skipped by user" -ForegroundColor Yellow
        continue
    }
    
    $scriptPath = Join-Path $PSScriptRoot $suite.Script
    
    if (Test-Path $scriptPath) {
        Write-TestSuite $suite.Name
        Write-Host "  Running: $($suite.Script)" -ForegroundColor Gray
        Write-Host ""
        
        try {
            # Run the test script
            $result = & $scriptPath
            
            # Check exit code
            if ($LASTEXITCODE -eq 0) {
                Add-TestResult -Suite $suite.Name -Test "Test Suite" -Status "PASS" -Message "All tests passed"
            }
            else {
                Add-TestResult -Suite $suite.Name -Test "Test Suite" -Status "FAIL" -Message "Some tests failed (exit code: $LASTEXITCODE)"
                
                if ($StopOnError) {
                    Write-Host ""
                    Write-Host "Stopping test execution due to failure (StopOnError flag)" -ForegroundColor Red
                    break
                }
            }
        }
        catch {
            Add-TestResult -Suite $suite.Name -Test "Test Suite" -Status "FAIL" -Message $_.Exception.Message
            
            if ($StopOnError) {
                Write-Host ""
                Write-Host "Stopping test execution due to error (StopOnError flag)" -ForegroundColor Red
                break
            }
        }
    }
    else {
        Write-TestSuite $suite.Name
        Add-TestResult -Suite $suite.Name -Test "Test Suite" -Status "SKIP" -Message "Script not found: $scriptPath"
    }
}

# Calculate execution time
$endTime = Get-Date
$duration = $endTime - $startTime

# Generate summary report
Write-Host ""
Write-Host ""
Write-Header "Test Execution Summary"

Write-Host "Execution Time: $($duration.ToString('mm\:ss'))" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test Results:" -ForegroundColor Cyan
Write-Host "  Total Tests:   $script:TotalTests"
Write-Host "  Passed:        " -NoNewline
Write-Host "$script:PassedTests" -ForegroundColor Green
Write-Host "  Failed:        " -NoNewline
Write-Host "$script:FailedTests" -ForegroundColor Red
Write-Host "  Skipped:       " -NoNewline
Write-Host "$script:SkippedTests" -ForegroundColor Yellow
Write-Host ""

if ($script:TotalTests -gt 0) {
    $passRate = [math]::Round(($script:PassedTests / $script:TotalTests) * 100, 2)
    Write-Host "  Pass Rate:     $passRate%" -ForegroundColor $(if ($passRate -eq 100) { "Green" } elseif ($passRate -ge 80) { "Yellow" } else { "Red" })
}

Write-Host ""
Write-Host "Detailed Results:" -ForegroundColor Cyan
Write-Host ""

# Group by suite
$groupedResults = $script:TestResults | Group-Object -Property Suite

foreach ($group in $groupedResults) {
    Write-Host "  $($group.Name):" -ForegroundColor Yellow
    foreach ($result in $group.Group) {
        $icon = switch ($result.Status) {
            "PASS" { "?" }
            "FAIL" { "?" }
            "SKIP" { "?" }
        }
        $color = switch ($result.Status) {
            "PASS" { "Green" }
            "FAIL" { "Red" }
            "SKIP" { "Yellow" }
        }
        Write-Host "    $icon $($result.Test)" -ForegroundColor $color
        if ($result.Message) {
            Write-Host "      $($result.Message)" -ForegroundColor Gray
        }
    }
    Write-Host ""
}

# Save detailed report to file
$reportPath = Join-Path $PSScriptRoot "test-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
$script:TestResults | Format-Table -AutoSize | Out-File -FilePath $reportPath
Write-Host "Detailed report saved to: $reportPath" -ForegroundColor Gray
Write-Host ""

# Final status
if ($script:FailedTests -eq 0) {
    Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Green
    Write-Host "?              ? ALL TESTS PASSED!                           ?" -ForegroundColor Green
    Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Red
    Write-Host "?              ? SOME TESTS FAILED                           ?" -ForegroundColor Red
    Write-Host "??????????????????????????????????????????????????????????????" -ForegroundColor Red
    exit 1
}
