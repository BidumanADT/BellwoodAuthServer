# AuthServer Phase 1 Testing Guide

**Purpose:** Verify Phase 1 userId claim implementation and JWT structure  
**Date:** January 11, 2026  
**Status:** Ready for Testing

---

## ?? Test Scenarios

### Test 1: Admin User Login - Verify userId Claim

**User:** alice (admin role)

**Request:**
```bash
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"password"}'
```

**Expected Response:**
```json
{
  "accessToken": "eyJ...",
  "refreshToken": "...",
  "access_token": "eyJ...",
  "refresh_token": "...",
  "token": "eyJ..."
}
```

**Verify JWT Claims (decode token at jwt.io):**
```json
{
  "sub": "alice",
  "uid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "userId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "role": "admin",
  "exp": 1704996000,
  "iat": 1704992400
}
```

**? Pass Criteria:**
- Token includes `userId` claim
- `userId` matches `uid` (both are Identity GUID)
- `role` is "admin"
- No `email` claim (alice doesn't have email configured)

---

### Test 2: Driver User Login - Custom UID vs userId

**User:** charlie (driver role with custom UID "driver-001")

**Request:**
```bash
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"charlie","password":"password"}'
```

**Expected JWT Claims:**
```json
{
  "sub": "charlie",
  "uid": "driver-001",
  "userId": "x9y8z7w6-v5u4-3t2s-1r0q-p0o9n8m7l6k5",
  "role": "driver",
  "exp": 1704996000,
  "iat": 1704992400
}
```

**? Pass Criteria:**
- `uid` is "driver-001" (custom value)
- `userId` is different from `uid` (Identity GUID)
- This proves the dual UID system works
- Driver assignment will use `uid`, audit will use `userId`

---

### Test 3: Booker User Login - Email Claim

**User:** chris (booker role with email)

**Request:**
```bash
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"chris","password":"password"}'
```

**Expected JWT Claims:**
```json
{
  "sub": "chris",
  "uid": "b2c3d4e5-f6g7-8h9i-0j1k-l2m3n4o5p6q7",
  "userId": "b2c3d4e5-f6g7-8h9i-0j1k-l2m3n4o5p6q7",
  "role": "booker",
  "email": "chris.bailey@example.com",
  "exp": 1704996000,
  "iat": 1704992400
}
```

**? Pass Criteria:**
- Includes `email` claim
- `userId` matches `uid` (both GUID)
- `role` is "booker"

---

### Test 4: OAuth2 Token Endpoint

**Request:**
```bash
curl -X POST https://localhost:5001/connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&username=alice&password=password&client_id=bellwood-maui-dev&scope=api.rides offline_access"
```

**Expected JWT Claims:**
```json
{
  "sub": "alice",
  "uid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "userId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "scope": "api.rides offline_access",
  "role": "admin",
  "exp": 1704996000,
  "iat": 1704992400
}
```

**? Pass Criteria:**
- Includes `userId` claim
- Includes `scope` claim
- Same structure as `/login` endpoint

---

### Test 5: Refresh Token Flow

**Step 1: Login to get refresh token**
```bash
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"password"}'
```

**Step 2: Use refresh token to get new access token**
```bash
curl -X POST https://localhost:5001/connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token&refresh_token=<REFRESH_TOKEN_FROM_STEP1>"
```

**? Pass Criteria:**
- New access token includes `userId` claim
- Claims structure identical to original login

---

### Test 6: Diagnostic Endpoint - JWT Preview

**Request:**
```bash
curl https://localhost:5001/dev/user-info/charlie
```

**Expected Response:**
```json
{
  "userId": "x9y8z7w6-v5u4-3t2s-1r0q-p0o9n8m7l6k5",
  "username": "charlie",
  "email": null,
  "roles": ["driver"],
  "userClaims": [
    { "type": "uid", "value": "driver-001" }
  ],
  "jwtClaimsPreview": [
    { "type": "sub", "value": "charlie" },
    { "type": "uid", "value": "driver-001" },
    { "type": "userId", "value": "x9y8z7w6-v5u4-3t2s-1r0q-p0o9n8m7l6k5" },
    { "type": "role", "value": "driver" }
  ],
  "diagnostics": {
    "hasDriverRole": true,
    "hasCustomUid": true,
    "customUidValue": "driver-001",
    "identityGuid": "x9y8z7w6-v5u4-3t2s-1r0q-p0o9n8m7l6k5",
    "hasEmail": false,
    "phase1Ready": true,
    "notes": {
      "uidClaim": "Custom UID will override default in JWT (driver pattern)",
      "userIdClaim": "Phase 1: userId claim always contains Identity GUID for audit tracking",
      "auditRecommendation": "AdminAPI should use 'userId' claim for CreatedByUserId field"
    }
  }
}
```

**? Pass Criteria:**
- `jwtClaimsPreview` shows Phase 1 structure
- Diagnostics show custom UID detection
- `phase1Ready` is `true`

---

### Test 7: All Test Users

**Test each user to verify correct claim structure:**

```bash
# Admin without email
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"bob","password":"password"}'

# Booker with email
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"chris","password":"password"}'

# Driver with GUID-based UID
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"driver_dave","password":"password"}'
```

**? Pass Criteria:**
- All tokens include `userId` claim
- Admin/booker: `uid` == `userId`
- Driver with custom UID: `uid` != `userId`
- Driver without custom UID: `uid` == `userId`

---

## ?? Manual JWT Inspection

### Decode Token at jwt.io

1. Copy `accessToken` from login response
2. Go to https://jwt.io
3. Paste token into "Encoded" field
4. Verify claims in "Decoded" section

### Expected Header:
```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```

### Expected Payload Structure:
```json
{
  "sub": "username",
  "uid": "identity-guid-or-custom",
  "userId": "always-identity-guid",
  "role": "admin|booker|driver",
  "email": "optional@example.com",
  "scope": "optional-for-oauth",
  "exp": 1704996000,
  "iat": 1704992400
}
```

---

## ?? Failure Scenarios

### Test 8: Invalid Credentials

**Request:**
```bash
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"wrongpassword"}'
```

**Expected Response:**
```
401 Unauthorized
```

**? Pass Criteria:**
- Returns 401 status
- No token issued

---

### Test 9: Missing Username/Password

**Request:**
```bash
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice"}'
```

**Expected Response:**
```json
{
  "error": "Username and password are required."
}
```

**? Pass Criteria:**
- Returns 400 Bad Request
- Descriptive error message

---

## ?? Phase 1 Verification Checklist

**Before marking Phase 1 complete, verify:**

- [ ] All login endpoints return `userId` claim
  - [ ] `/login`
  - [ ] `/api/auth/login`
  - [ ] `/connect/token` (password grant)
  - [ ] `/connect/token` (refresh token grant)

- [ ] Dual UID system working
  - [ ] Regular users: `uid` == `userId` (both GUID)
  - [ ] Drivers with custom UID: `uid` is custom, `userId` is GUID
  - [ ] Drivers without custom UID: `uid` == `userId` (both GUID)

- [ ] Email claims working
  - [ ] Users with email claim: included in JWT
  - [ ] Users with `user.Email` property: included in JWT
  - [ ] Users without email: no email claim in JWT

- [ ] Diagnostic endpoint working
  - [ ] Shows JWT preview with `userId`
  - [ ] Detects custom UIDs correctly
  - [ ] Phase 1 ready flag is true

- [ ] Backward compatibility
  - [ ] No breaking changes to existing endpoints
  - [ ] Existing test users still work
  - [ ] Token expiration unchanged

---

## ?? Integration Testing with AdminAPI

### Test 10: AdminAPI CreatedByUserId Field

**Prerequisites:**
- AuthServer running on localhost:5001
- AdminAPI running and updated for Phase 1

**Steps:**

1. **Login as booker:**
   ```bash
   curl -X POST https://localhost:5001/login \
     -H "Content-Type: application/json" \
     -d '{"username":"chris","password":"password"}'
   ```

2. **Extract JWT token from response**

3. **Create a booking in AdminAPI:**
   ```bash
   curl -X POST https://localhost:7100/bookings \
     -H "Authorization: Bearer <JWT_TOKEN>" \
     -H "Content-Type: application/json" \
     -d '{...booking data...}'
   ```

4. **Verify booking record has CreatedByUserId:**
   - Should be set to chris's Identity GUID (from `userId` claim)
   - NOT the email address
   - Should match the `userId` claim in the JWT

**? Pass Criteria:**
- AdminAPI extracts `userId` claim
- Stores it in `CreatedByUserId` field
- Can query bookings by `CreatedByUserId`

---

## ?? Test Results Template

```markdown
## Phase 1 Test Results - AuthServer

**Date:** _____________________  
**Tester:** _____________________  
**Build:** _____________________

### Test Summary

| Test # | Test Name | Status | Notes |
|--------|-----------|--------|-------|
| 1 | Admin user login | ? Pass / ? Fail | |
| 2 | Driver custom UID | ? Pass / ? Fail | |
| 3 | Booker with email | ? Pass / ? Fail | |
| 4 | OAuth2 endpoint | ? Pass / ? Fail | |
| 5 | Refresh token | ? Pass / ? Fail | |
| 6 | Diagnostic endpoint | ? Pass / ? Fail | |
| 7 | All test users | ? Pass / ? Fail | |
| 8 | Invalid credentials | ? Pass / ? Fail | |
| 9 | Missing fields | ? Pass / ? Fail | |
| 10 | AdminAPI integration | ? Pass / ? Fail | |

### Issues Found

1. _____________________
2. _____________________

### Phase 1 Sign-off

- [ ] All tests passed
- [ ] No critical issues
- [ ] Documentation accurate
- [ ] Ready for Phase 2

**Approved By:** _____________________  
**Date:** _____________________
```

---

**Status:** ? **READY FOR TESTING**  
**Version:** 1.0  
**Last Updated:** January 11, 2026

---

*Complete these tests to verify AuthServer Phase 1 implementation before proceeding to Phase 2.* ???
