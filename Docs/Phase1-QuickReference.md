# Quick Reference - Phase 1 Changes

**For developers needing quick answers about Phase 1 changes**

---

## ?? What Changed?

### JWT Now Contains `userId` Claim

**Before Phase 1:**
```json
{
  "sub": "alice",
  "uid": "guid-xxx",
  "role": "admin"
}
```

**After Phase 1:**
```json
{
  "sub": "alice",
  "uid": "guid-xxx",
  "userId": "guid-xxx",  // ? NEW
  "role": "admin"
}
```

---

## ?? Why userId?

- **Consistent format:** Always an Identity GUID
- **Audit tracking:** Use for `CreatedByUserId` field
- **Driver support:** Drivers keep custom `uid` but have Identity GUID in `userId`

---

## ?? Driver Tokens Special Case

**Driver Token:**
```json
{
  "sub": "charlie",
  "uid": "driver-001",           // Custom UID for assignment
  "userId": "a1b2c3d4-...",      // Identity GUID for audit
  "role": "driver"
}
```

**Why different?**
- `uid`: Used to match `AssignedDriverUid` in bookings
- `userId`: Used for audit trail (`CreatedByUserId`)

---

## ?? How to Use in AdminAPI

```csharp
// Get userId for audit tracking
var userId = User.FindFirstValue("userId");

// Fallback for backward compatibility
if (string.IsNullOrEmpty(userId))
{
    userId = User.FindFirstValue("uid");
}

// Store in CreatedByUserId
booking.CreatedByUserId = userId;
```

---

## ?? Quick Test

```bash
# Login
curl -X POST https://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"password"}'

# Decode token at jwt.io
# Look for "userId" claim
```

---

## ?? Files Changed

- `Program.cs` - Both login endpoints updated
- `Controllers/TokenController.cs` - OAuth endpoint updated
- `Data/Phase2RolePreparation.cs` - New file (Phase 2 ready)

---

## ?? Phase 2 Activation

When ready for Phase 2:

1. Open `Program.cs`
2. Find: `// PHASE 2 ACTIVATION:`
3. Uncomment the next line
4. Restart server

---

## ?? Full Documentation

- **Implementation:** `Docs/AuthServer-Phase1_Implementation.md`
- **Testing:** `Docs/AuthServer-Phase1_Testing.md`
- **Summary:** `Docs/AuthServer-Phase1_Complete.md`

---

**Quick Answer:** Use `userId` claim for all audit tracking. It's always an Identity GUID.
