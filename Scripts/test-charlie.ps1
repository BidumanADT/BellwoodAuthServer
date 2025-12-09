# Test Charlie's Login and Decode Token
# Compatible with PowerShell 5.1+

# Bypass SSL certificate validation for localhost (PowerShell 5.1 compatible)
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

# Force TLS 1.2 (required for HTTPS)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "`n=== STEP 1: Check if AuthServer is Running ===" -ForegroundColor Cyan
try {
    $health = Invoke-RestMethod -Uri "https://localhost:5001/health"
    Write-Host "? AuthServer is running" -ForegroundColor Green
} catch {
    Write-Host "? AuthServer is not running! Start it with 'dotnet run'" -ForegroundColor Red
    exit
}

Write-Host "`n=== STEP 2: Check Charlie's Configuration ===" -ForegroundColor Cyan
try {
    $userInfo = Invoke-RestMethod -Uri "https://localhost:5001/dev/user-info/charlie"
    Write-Host "User ID: $($userInfo.userId)"
    Write-Host "Username: $($userInfo.username)"
    Write-Host "Roles: $($userInfo.roles -join ', ')"
    Write-Host "Claims:"
    foreach ($claim in $userInfo.claims) {
        Write-Host "  - $($claim.type): $($claim.value)"
    }
    
    if ($userInfo.diagnostics.hasDriverRole) {
        Write-Host "? Charlie has driver role" -ForegroundColor Green
    } else {
        Write-Host "? Charlie is MISSING driver role!" -ForegroundColor Red
    }
    
    if ($userInfo.diagnostics.hasUidClaim) {
        Write-Host "? Charlie has uid claim: $($userInfo.diagnostics.uidValue)" -ForegroundColor Green
    } else {
        Write-Host "? Charlie is MISSING uid claim!" -ForegroundColor Red
    }
} catch {
    Write-Host "? Error checking user info: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== STEP 3: Login as Charlie ===" -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Uri "https://localhost:5001/api/auth/login" `
        -Method POST `
        -Body '{"username":"charlie","password":"password"}' `
        -ContentType "application/json"
    
    Write-Host "? Login successful!" -ForegroundColor Green
    
    $token = $response.accessToken
    Write-Host "`n=== JWT TOKEN (Copy this EXACT string) ===" -ForegroundColor Yellow
    Write-Host $token -ForegroundColor White
    
    # Save to file
    $token | Out-File -FilePath "charlie-token.txt" -Encoding ASCII
    Write-Host "`n? Token saved to charlie-token.txt" -ForegroundColor Green
    
    # Decode the payload (basic decode, won't verify signature)
    Write-Host "`n=== DECODED TOKEN (Payload Only) ===" -ForegroundColor Cyan
    $parts = $token.Split('.')
    if ($parts.Length -ge 2) {
        $payload = $parts[1]
        # Add padding if needed
        while ($payload.Length % 4 -ne 0) {
            $payload += "="
        }
        
        try {
            $decoded = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload))
            $json = $decoded | ConvertFrom-Json
            
            Write-Host "Payload Contents:" -ForegroundColor Cyan
            Write-Host "  sub (username): $($json.sub)"
            Write-Host "  uid (driver id): $($json.uid)"
            Write-Host "  role: $($json.role)"
            $expDate = [DateTimeOffset]::FromUnixTimeSeconds($json.exp).LocalDateTime
            Write-Host "  exp (expires): $expDate"
            
            Write-Host "`n=== TOKEN ANALYSIS ===" -ForegroundColor Cyan
            if ($json.role) {
                Write-Host "? Token has 'role' claim: $($json.role)" -ForegroundColor Green
            } else {
                Write-Host "? Token MISSING 'role' claim! This will cause 403!" -ForegroundColor Red
            }
            
            if ($json.uid) {
                Write-Host "? Token has 'uid' claim: $($json.uid)" -ForegroundColor Green
            } else {
                Write-Host "? Token MISSING 'uid' claim!" -ForegroundColor Red
            }
            
            # Check if token is expired
            if ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -gt $json.exp) {
                Write-Host "??  Token is EXPIRED! Get a new one." -ForegroundColor Yellow
            } else {
                Write-Host "? Token is still valid" -ForegroundColor Green
            }
        } catch {
            Write-Host "? Error decoding payload: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "`n=== NEXT STEPS ===" -ForegroundColor Yellow
    Write-Host "To use jwt.io:"
    Write-Host "1. Copy ONLY the token above (the long string without quotes)"
    Write-Host "2. Go to https://jwt.io"
    Write-Host "3. Delete the example token in the 'Encoded' box"
    Write-Host "4. Paste your token (just the token, no JSON)"
    Write-Host "5. Check the 'PAYLOAD' section for 'role': 'driver'"
    Write-Host "`nOr just read the decoded output above! ??" -ForegroundColor Green
    
} catch {
    Write-Host "? Login failed: $($_.Exception.Message)" -ForegroundColor Red
}