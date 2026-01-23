# Admin Portal - Phase 1 Integration Reference

**Initiative:** User-Specific Data Access Enforcement  
**Component:** Admin Portal (Blazor)  
**Phase:** Phase 1 - AuthServer & AdminAPI Changes Reference  
**Date:** January 11, 2026  
**Status:** ?? **INFORMATIONAL**

---

## ?? Purpose of This Document

This document describes the Phase 1 changes completed by the **AuthServer** and **AdminAPI** teams that may affect the Admin Portal. It is provided for **reference only** to help the Portal team understand what changed in the backend systems.

**This document does NOT contain implementation instructions for the Admin Portal team.**

---

## ?? What Changed in Phase 1

### ? **AuthServer Phase 1 Changes** (Complete)

**Summary:** AuthServer now includes a `userId` claim in all JWT tokens.

**JWT Structure Change:**

**Before Phase 1:**
```json
{
  "sub": "alice",
  "uid": "a1b2c3d4-...",
  "role": "admin"
}
```

**After Phase 1:**
```json
{
  "sub": "alice",
  "uid": "a1b2c3d4-...",
  "userId": "a1b2c3d4-...",  // ? NEW
  "role": "admin"
}
```

**What This Means:**
- All JWT tokens now contain a `userId` claim
- The `userId` claim always contains the Identity GUID
- For drivers with custom UIDs: `uid` is custom, `userId` is the Identity GUID
- The change is backward compatible (existing tokens will expire naturally)

**Portal Impact:**
- Portal's existing JWT handling continues to work unchanged
- The new `userId` claim is available if needed in the future

**Reference Documentation:**
- `Docs/AuthServer-Phase1_Implementation.md` - Complete details
- `Docs/Phase1-QuickReference.md` - Quick reference

---

### ? **AdminAPI Phase 1 Changes** (Complete)

**Summary:** AdminAPI now tracks ownership and filters data by user role.

**Data Model Changes:**

All booking and quote records now include three new fields:
- `createdByUserId` - Who created the record (GUID from JWT `userId` claim)
- `modifiedByUserId` - Who last modified the record (GUID)
- `modifiedOnUtc` - When the record was last modified (DateTime)

**API Response Changes:**

**Example Booking Response (Before Phase 1):**
```json
{
  "bookingId": "BK-123",
  "passengerName": "John Doe",
  "status": "Confirmed",
  "createdUtc": "2026-01-10T10:00:00Z"
}
```

**Example Booking Response (After Phase 1):**
```json
{
  "bookingId": "BK-123",
  "passengerName": "John Doe",
  "status": "Confirmed",
  "createdUtc": "2026-01-10T10:00:00Z",
  "createdByUserId": "a1b2c3d4-...",      // ? NEW
  "modifiedByUserId": "x9y8z7w6-...",     // ? NEW
  "modifiedOnUtc": "2026-01-10T15:30:00Z" // ? NEW
}
```

**Authorization Changes:**

AdminAPI now filters data based on user role:

| User Role | What They See |
|-----------|---------------|
| **Admin** | All bookings and quotes |
| **Booker** | Only records they created (`createdByUserId` matches their `userId`) |
| **Driver** | Only bookings assigned to them (`assignedDriverUid` matches their `uid`) |

**Error Response Changes:**

AdminAPI may now return `403 Forbidden` when a user attempts to access a record they don't own:

```json
{
  "error": "You don't have permission to access this booking."
}
```

**Legacy Data Handling:**

Records created before Phase 1 have `createdByUserId: null`. These records are only visible to admin users.

**Portal Impact:**
- API responses now include three additional fields
- API automatically filters results based on the user's role
- API may return 403 Forbidden for unauthorized access attempts
- Portal will receive only the data the current user is authorized to see

**Reference Documentation:**
- `Docs/API-Phase1_Data_Access_Implementation.md` - Complete details

---

## ?? JWT Claims Reference

### What the Portal Receives from AuthServer

**Admin User Token:**
```json
{
  "sub": "alice",
  "uid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "userId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "role": "admin",
  "exp": 1704996000
}
```

**Driver User Token:**
```json
{
  "sub": "charlie",
  "uid": "driver-001",
  "userId": "x9y8z7w6-v5u4-3t2s-1r0q-p0o9n8m7l6k5",
  "role": "driver",
  "exp": 1704996000
}
```

**Accessing Claims in Blazor (Reference Only):**
```csharp
@inject AuthenticationStateProvider AuthenticationStateProvider

@code {
    private async Task<string?> GetCurrentUserId()
    {
        var authState = await AuthenticationStateProvider.GetAuthenticationStateAsync();
        var user = authState.User;
        
        // userId claim (always GUID)
        var userId = user.FindFirst("userId")?.Value;
        
        // Fallback to uid if userId not present
        if (string.IsNullOrEmpty(userId))
        {
            userId = user.FindFirst("uid")?.Value;
        }
        
        return userId;
    }
}
```

---

## ?? API Response Format Reference

### Booking List Endpoint: `GET /bookings/list`

**Response Format (Phase 1):**
```json
[
  {
    "bookingId": "BK-123",
    "passengerName": "John Doe",
    "status": "Confirmed",
    "createdUtc": "2026-01-10T10:00:00Z",
    "createdByUserId": "a1b2c3d4-...",
    "modifiedByUserId": "x9y8z7w6-...",
    "modifiedOnUtc": "2026-01-10T15:30:00Z"
  }
]
```

**Filtering Behavior:**
- Admin users receive all bookings
- Booker users receive only bookings they created
- Driver users receive only bookings assigned to them

---

### Booking Detail Endpoint: `GET /bookings/{id}`

**Success Response (200 OK):**
```json
{
  "bookingId": "BK-123",
  "passengerName": "John Doe",
  "status": "Confirmed",
  "createdUtc": "2026-01-10T10:00:00Z",
  "createdByUserId": "a1b2c3d4-...",
  "modifiedByUserId": "x9y8z7w6-...",
  "modifiedOnUtc": "2026-01-10T15:30:00Z"
}
```

**Unauthorized Response (403 Forbidden):**
```json
{
  "error": "You don't have permission to access this booking."
}
```

**Authorization Behavior:**
- Admin users can access any booking
- Booker users can only access bookings they created
- Driver users can only access bookings assigned to them
- Unauthorized attempts return 403 Forbidden

---

### Cancel Booking Endpoint: `POST /bookings/{id}/cancel`

**Authorization Behavior:**
- Verifies user has permission to cancel
- Returns 403 Forbidden if user doesn't own the booking (unless admin)
- Updates `modifiedByUserId` and `modifiedOnUtc` in audit trail

---

### Quote Endpoints: Similar Changes

Quote endpoints (`GET /quotes/list`, `GET /quotes/{id}`) have the same audit fields and authorization behavior as booking endpoints.

---

## ?? Data Flow Reference

### How Ownership Tracking Works

1. **User logs into Portal** ? Gets JWT from AuthServer
2. **JWT contains `userId` claim** ? Identity GUID of the logged-in user
3. **Portal calls AdminAPI** ? Sends JWT in Authorization header
4. **AdminAPI extracts `userId`** ? From JWT claims
5. **AdminAPI creates/updates record** ? Stores `userId` in `createdByUserId` or `modifiedByUserId`
6. **AdminAPI returns response** ? Includes audit fields
7. **Portal receives data** ? Already filtered by AdminAPI based on user role

**Key Point:** AdminAPI handles all filtering automatically. Portal receives only data the user is authorized to see.

---

## ?? Legacy Data Handling

**Records created before Phase 1:**
- Have `createdByUserId: null`
- Have `modifiedByUserId: null`
- Have `modifiedOnUtc: null`

**Visibility:**
- Only visible to admin users
- Non-admin users will NOT see these records in list endpoints

**Reference:** Portal should be prepared to handle null values in audit fields.

---

## ?? Integration Points

### AuthServer
- **What Portal Uses:** Login endpoint, JWT tokens
- **What Changed:** JWT now includes `userId` claim
- **Portal Impact:** None (backward compatible)

### AdminAPI
- **What Portal Uses:** All booking/quote endpoints
- **What Changed:** Responses include audit fields, role-based filtering, 403 errors
- **Portal Impact:** Responses have new fields, may receive 403 errors

---

## ?? Phase 2 Preview (Not Implemented)

**Future Changes (Phase 2):**
- Dispatcher role will be activated in AuthServer
- Authorization policies will be enforced (AdminOnly, StaffOnly)
- Field masking for sensitive data (dispatchers won't see billing)
- Role-based UI changes in Portal

**Phase 1 Focus:**
- Ownership tracking ? (AuthServer & AdminAPI complete)
- Basic access filtering ? (AdminAPI complete)
- Audit trail available in API responses ?

---

## ?? Reference Documentation

**For Understanding AuthServer Changes:**
- `Docs/AuthServer-Phase1_Implementation.md` - Complete implementation details
- `Docs/AuthServer-Phase1_Testing.md` - Test scenarios and JWT examples
- `Docs/Phase1-QuickReference.md` - Quick developer reference

**For Understanding AdminAPI Changes:**
- `Docs/API-Phase1_Data_Access_Implementation.md` - Implementation summary

**For Understanding Overall Platform:**
- `Docs/Phase1-Platform-Summary.md` - All three components overview
- `Docs/Phase1-DataFlow-Reference.md` - Visual data flow diagrams
- `Docs/Planning-DataAccessEnforcement.md` - Overall strategy

---

## ?? Questions & Answers

### Q: Do I need to change my JWT handling code?
**A:** No. The new `userId` claim is added automatically. Existing JWT handling continues to work.

---

### Q: Will my API calls break?
**A:** No. API responses now include additional fields, but existing fields remain unchanged. The change is backward compatible.

---

### Q: What if I see a 403 error?
**A:** AdminAPI now returns 403 Forbidden when a user attempts to access data they don't own. This is expected behavior.

---

### Q: What are these new fields in the response?
**A:** `createdByUserId`, `modifiedByUserId`, and `modifiedOnUtc` are audit fields added in Phase 1 to track who created/modified each record.

---

### Q: Why are some of these fields null?
**A:** Records created before Phase 1 have null audit fields. This is expected for legacy data.

---

### Q: Do I need to filter bookings by user?
**A:** No. AdminAPI filters automatically based on the user's role. Portal receives only data the user is authorized to see.

---

### Q: Where can I find implementation instructions for the Portal?
**A:** Implementation instructions will be provided separately when the team is ready. This document is for reference only.

---

## ? Summary

**What Changed:**
- AuthServer: Added `userId` claim to JWTs ?
- AdminAPI: Added audit fields, role-based filtering, ownership verification ?

**Portal Impact:**
- JWT tokens have an additional claim (backward compatible)
- API responses have additional fields (backward compatible)
- API may return 403 Forbidden (new behavior)
- API automatically filters data by role (new behavior)

**Portal Action Required:**
- **None at this time.** Implementation guidance will be provided separately.

---

**Status:** ?? **INFORMATIONAL REFERENCE**  
**Purpose:** Inform Portal team of backend changes  
**Audience:** Admin Portal development team  
**Next Steps:** Await implementation guidance from project lead  

---

*This document describes what the AuthServer and AdminAPI teams completed in Phase 1. Implementation instructions for the Admin Portal will be provided separately.* ???
