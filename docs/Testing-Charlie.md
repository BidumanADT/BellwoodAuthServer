# Testing Charlie's Driver Access - Step by Step

## Prerequisites

1. AuthServer running on `https://localhost:5001`
2. AdminAPI running on `https://localhost:5000` (or appropriate port)
3. A terminal or REST client (curl, Postman, etc.)

---

## Test Sequence

### Test 1: Verify Charlie Exists and Has Correct Configuration

**Request:**
```bash
curl -k https://localhost:5001/dev/user-info/charlie
```

**Expected Response:**
```json
{
  "userId": "some-guid",
  "username": "charlie",
  "email": null,
  "roles": ["driver"],
  "claims": [
    {
      "type": "uid",
      "value": "driver-001"
    }
  ],
  "diagnostics": {
    "hasDriverRole": true,
    "hasUidClaim": true,
    "uidValue": "driver-001",
    "canAccessDriverEndpoints": true,
    "warning": null
  }
}
```

**If You See Problems:**

| Problem | Symptom | Fix |
|---------|---------|-----|
| User not found | 404 status | Restart AuthServer to trigger seed |
| `"roles": []` | Missing driver role | Restart AuthServer |
| `"claims": []` | Missing uid claim | Restart AuthServer |
| Wrong uid value | `uidValue` not "driver-001" | Restart AuthServer |

---

### Test 2: Login as Charlie

**Request:**
```bash
curl -k -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username": "charlie", "password": "password"}'
```

**Expected Response:**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "abc123def456...",
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "abc123def456...",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Save the `accessToken` value** - you'll need it for the next tests.

---

### Test 3: Decode and Verify JWT Token

**Go to https://jwt.io**

1. Paste the `accessToken` from Test 2 into the "Encoded" section
2. Check the "Decoded" payload section

**Expected Payload:**
```json
{
  "sub": "charlie",
  "uid": "driver-001",
  "role": "driver",
  "exp": 1234567890,
  "iat": 1234567890
}
```

**Critical Checks:**
- ? `"role": "driver"` must be present
- ? `"uid": "driver-001"` must match Driver.UserUid in AdminAPI
- ? Token must not be expired (`exp` > current Unix timestamp)

**Common Issues:**

| Issue | Symptom | Cause |
|-------|---------|-------|
| No "role" claim | Payload missing role | Charlie missing driver role in DB |
| Wrong uid | `"uid": "different-value"` | Seed script used wrong uid |
| Expired token | `exp` in past | Need fresh token (re-run Test 2) |

---

### Test 4: Test Protected /api/auth/me Endpoint (AuthServer)

This verifies the token is being parsed correctly by the AuthServer itself.

**Request:**
```bash
curl -k https://localhost:5001/api/auth/me \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN_HERE"
```

**Replace `YOUR_ACCESS_TOKEN_HERE`** with the actual token from Test 2.

**Expected Response:**
```json
{
  "user": "charlie",
  "claims": [
    { "type": "sub", "value": "charlie" },
    { "type": "uid", "value": "driver-001" },
    { "type": "role", "value": "driver" },
    { "type": "exp", "value": "1234567890" }
  ]
}
```

**If This Fails:**

| Status | Meaning | Fix |
|--------|---------|-----|
| 401 | Token invalid/expired | Get new token (Test 2) |
| 403 | (Unlikely here) | Check AuthServer configuration |
| 500 | Server error | Check AuthServer logs |

---

### Test 5: Test Driver Endpoint (AdminAPI)

**IMPORTANT:** Replace the URL/port with your actual AdminAPI endpoint.

**Request:**
```bash
curl -k https://localhost:5000/driver/rides/today \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN_HERE"
```

**Expected Response (Success):**
```json
[
  {
    "id": "booking123",
    "pickupLocation": "123 Main St",
    "dropoffLocation": "456 Oak Ave",
    "pickupTime": "2024-01-15T10:00:00Z",
    "status": "Assigned"
  }
]
```

Or empty array if no rides:
```json
[]
```

**Status Codes:**

| Status | Meaning | What It Tells You |
|--------|---------|-------------------|
| 200 OK | ? Success | Role claim present and valid |
| 401 Unauthorized | Token rejected | Signature mismatch or expired |
| 403 Forbidden | ? Role missing | Token has no "role": "driver" claim |
| 404 Not Found | Wrong endpoint | Check AdminAPI routes |
| 500 Server Error | AdminAPI problem | Check AdminAPI logs |

---

## Troubleshooting 403 Errors

If Test 5 returns **403 Forbidden**, work backwards:

### Step A: Verify Token Has Role Claim (Test 3)
- Go to jwt.io and decode the token
- Look for `"role": "driver"` in the payload
- **If missing:** Charlie's user record is missing the role ? Go to Step B

### Step B: Verify Charlie's Configuration (Test 1)
- Run `/dev/user-info/charlie`
- Check `diagnostics.hasDriverRole`
- **If false:** Restart AuthServer to trigger seed

### Step C: Get Fresh Token (Test 2)
- Old tokens don't update when roles change
- Login again to get new token with updated claims
- Re-run Test 5 with new token

### Step D: Check AdminAPI Configuration
If token has correct role claim but still getting 403:

**Possible Issues:**
1. **Different JWT signing key** - AdminAPI can't validate AuthServer tokens
2. **Wrong role claim type** - AdminAPI expects `ClaimTypes.Role` instead of `"role"`
3. **Endpoint configuration** - AdminAPI using wrong authorization attribute

**Verify AdminAPI JWT setup:**
```csharp
// These MUST match in both servers
var key = new SymmetricSecurityKey(
    Encoding.UTF8.GetBytes("super-long-jwt-signing-secret-1234"));
```

---

## Complete Test Script

Run this entire script to test the full flow:

```bash
#!/bin/bash

echo "=== Test 1: Check Charlie's Configuration ==="
curl -k https://localhost:5001/dev/user-info/charlie
echo -e "\n"

echo "=== Test 2: Login as Charlie ==="
RESPONSE=$(curl -k -s -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username": "charlie", "password": "password"}')
echo $RESPONSE
echo -e "\n"

TOKEN=$(echo $RESPONSE | jq -r '.accessToken')
echo "Access Token: $TOKEN"
echo -e "\n"

echo "=== Test 3: Decode Token (copy to jwt.io) ==="
echo $TOKEN
echo -e "\n"

echo "=== Test 4: Test AuthServer /me Endpoint ==="
curl -k https://localhost:5001/api/auth/me \
  -H "Authorization: Bearer $TOKEN"
echo -e "\n"

echo "=== Test 5: Test AdminAPI Driver Endpoint ==="
curl -k https://localhost:5000/driver/rides/today \
  -H "Authorization: Bearer $TOKEN"
echo -e "\n"

echo "=== Done ==="
```

**Save as `test-charlie.sh` and run:**
```bash
chmod +x test-charlie.sh
./test-charlie.sh
```

---

## PowerShell Version (Windows)

```powershell
Write-Host "=== Test 1: Check Charlie's Configuration ===" -ForegroundColor Cyan
Invoke-RestMethod -Uri "https://localhost:5001/dev/user-info/charlie" -SkipCertificateCheck

Write-Host "`n=== Test 2: Login as Charlie ===" -ForegroundColor Cyan
$loginBody = @{
    username = "charlie"
    password = "password"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "https://localhost:5001/login" `
    -Method POST `
    -Body $loginBody `
    -ContentType "application/json" `
    -SkipCertificateCheck

$token = $response.accessToken
Write-Host "Access Token: $token"

Write-Host "`n=== Test 4: Test AuthServer /me Endpoint ===" -ForegroundColor Cyan
$headers = @{
    Authorization = "Bearer $token"
}
Invoke-RestMethod -Uri "https://localhost:5001/api/auth/me" `
    -Headers $headers `
    -SkipCertificateCheck

Write-Host "`n=== Test 5: Test AdminAPI Driver Endpoint ===" -ForegroundColor Cyan
try {
    Invoke-RestMethod -Uri "https://localhost:5000/driver/rides/today" `
        -Headers $headers `
        -SkipCertificateCheck
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
}

Write-Host "`n=== Done ===" -ForegroundColor Green
```

**Save as `Test-Charlie.ps1` and run:**
```powershell
.\Test-Charlie.ps1
```

---

## Success Indicators

You know everything is working when:

1. ? Test 1 shows `"hasDriverRole": true`
2. ? Test 2 returns access token
3. ? Test 3 (jwt.io) shows `"role": "driver"`
4. ? Test 4 returns user info with role claim
5. ? Test 5 returns 200 OK (not 403)

If all tests pass, Charlie can successfully:
- Authenticate with AuthServer
- Receive JWT with driver role
- Access driver-only endpoints in AdminAPI
- See his assigned rides in the DriverApp
