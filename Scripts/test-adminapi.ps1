# Test AdminAPI Driver Endpoint with Charlie's Token
# Run this after getting a fresh token from test-charlie.ps1

# Bypass SSL certificate validation for localhost
if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
    $certCallback = @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            if(ServicePointManager.ServerCertificateValidationCallback == null)
            {
                ServicePointManager.ServerCertificateValidationCallback += 
                    delegate
                    (
                        Object obj, 
                        X509Certificate certificate, 
                        X509Chain chain, 
                        SslPolicyErrors errors
                    )
                    {
                        return true;
                    };
            }
        }
    }
"@
    Add-Type $certCallback
}
[ServerCertificateValidationCallback]::Ignore()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "`n=== COMPLETE CHARLIE TEST - AuthServer + AdminAPI ===" -ForegroundColor Magenta

# Step 1: Check AuthServer
Write-Host "`n=== STEP 1: Check AuthServer ===" -ForegroundColor Cyan
try {
    $health = Invoke-RestMethod -Uri "https://localhost:5001/health"
    Write-Host "? AuthServer is running" -ForegroundColor Green
} catch {
    Write-Host "? AuthServer is NOT running! Start it first." -ForegroundColor Red
    exit
}

# Step 2: Check AdminAPI
Write-Host "`n=== STEP 2: Check AdminAPI ===" -ForegroundColor Cyan
try {
    $health = Invoke-RestMethod -Uri "https://localhost:5206/health"
    Write-Host "? AdminAPI is running" -ForegroundColor Green
} catch {
    Write-Host "? AdminAPI is NOT running! Start it with 'dotnet run' in AdminAPI directory" -ForegroundColor Red
    exit
}

# Step 3: Check Charlie's configuration
Write-Host "`n=== STEP 3: Check Charlie's Configuration ===" -ForegroundColor Cyan
try {
    $userInfo = Invoke-RestMethod -Uri "https://localhost:5001/dev/user-info/charlie"
    
    if ($userInfo.diagnostics.hasDriverRole) {
        Write-Host "? Charlie has driver role" -ForegroundColor Green
    } else {
        Write-Host "? Charlie is MISSING driver role!" -ForegroundColor Red
        exit
    }
    
    if ($userInfo.diagnostics.hasUidClaim) {
        Write-Host "? Charlie has uid claim: $($userInfo.diagnostics.uidValue)" -ForegroundColor Green
    } else {
        Write-Host "? Charlie is MISSING uid claim!" -ForegroundColor Red
        exit
    }
} catch {
    Write-Host "? Error checking Charlie's configuration" -ForegroundColor Red
    exit
}

# Step 4: Login as Charlie
Write-Host "`n=== STEP 4: Login as Charlie ===" -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Uri "https://localhost:5001/api/auth/login" `
        -Method POST `
        -Body '{"username":"charlie","password":"password"}' `
        -ContentType "application/json"
    
    Write-Host "? Login successful!" -ForegroundColor Green
    
    $token = $response.accessToken
    
    # Decode payload
    $parts = $token.Split('.')
    if ($parts.Length -ge 2) {
        $payload = $parts[1]
        while ($payload.Length % 4 -ne 0) { $payload += "=" }
        $decoded = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload))
        $json = $decoded | ConvertFrom-Json
        
        Write-Host "`nToken Claims:" -ForegroundColor Cyan
        Write-Host "  sub: $($json.sub)"
        Write-Host "  role: $($json.role)"
        Write-Host "  uid: $($json.uid)"
        
        if ($json.role -eq "driver") {
            Write-Host "  ? Token has driver role" -ForegroundColor Green
        } else {
            Write-Host "  ? Token missing driver role!" -ForegroundColor Red
            exit
        }
    }
} catch {
    Write-Host "? Login failed: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# Step 5: Test AdminAPI Driver Endpoint
Write-Host "`n=== STEP 5: Test AdminAPI Driver Endpoint ===" -ForegroundColor Cyan
Write-Host "Calling: GET https://localhost:5206/driver/rides/today" -ForegroundColor Gray
Write-Host "Authorization: Bearer <token>" -ForegroundColor Gray

$headers = @{
    Authorization = "Bearer $token"
}

try {
    $rides = Invoke-RestMethod -Uri "https://localhost:5206/driver/rides/today" `
        -Headers $headers `
        -Method GET
    
    Write-Host "`n? ? ? SUCCESS! Status: 200 OK ? ? ?" -ForegroundColor Green -BackgroundColor DarkGreen
    Write-Host "`nCharlie's rides today:" -ForegroundColor Cyan
    
    if ($rides.Count -eq 0) {
        Write-Host "  No rides scheduled for today (this is OK - run seed endpoint if needed)" -ForegroundColor Yellow
    } else {
        foreach ($ride in $rides) {
            Write-Host "`n  ?? Ride ID: $($ride.id)" -ForegroundColor White
            Write-Host "     Pickup: $($ride.pickupDateTime)" -ForegroundColor Gray
            Write-Host "     From: $($ride.pickupLocation)" -ForegroundColor Gray
            Write-Host "     To: $($ride.dropoffLocation)" -ForegroundColor Gray
            Write-Host "     Passenger: $($ride.passengerName) ($($ride.passengerPhone))" -ForegroundColor Gray
            Write-Host "     Status: $($ride.status)" -ForegroundColor Gray
        }
        Write-Host "`n  Total rides: $($rides.Count)" -ForegroundColor Cyan
    }
    
    Write-Host "`n=== ? ALL TESTS PASSED! ===" -ForegroundColor Green -BackgroundColor DarkGreen
    Write-Host "Charlie can successfully authenticate and access his rides!" -ForegroundColor Green
    Write-Host "The driver app should now work correctly." -ForegroundColor Green
    
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "`n? ? ? FAILED! Status: $statusCode ? ? ?" -ForegroundColor Red -BackgroundColor DarkRed
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($statusCode -eq 401) {
        Write-Host "`n?? Diagnosis: 401 Unauthorized" -ForegroundColor Yellow
        Write-Host "  - Token signature validation failed" -ForegroundColor Yellow
        Write-Host "  - Check that AdminAPI and AuthServer use the SAME JWT key" -ForegroundColor Yellow
        Write-Host "  - Check AdminAPI console for 'Authentication FAILED' message" -ForegroundColor Yellow
    }
    elseif ($statusCode -eq 403) {
        Write-Host "`n?? Diagnosis: 403 Forbidden" -ForegroundColor Yellow
        Write-Host "  - Token is valid but authorization failed" -ForegroundColor Yellow
        Write-Host "  - Check AdminAPI console for 'Authorization FORBIDDEN' message" -ForegroundColor Yellow
        Write-Host "  - The console will show if the role claim is missing or not recognized" -ForegroundColor Yellow
    }
    
    Write-Host "`n?? Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Check the AdminAPI console output (it will show detailed auth logs)" -ForegroundColor White
    Write-Host "2. Look for messages starting with ?, ??, or ??" -ForegroundColor White
    Write-Host "3. The logs will tell you exactly what went wrong" -ForegroundColor White
}
