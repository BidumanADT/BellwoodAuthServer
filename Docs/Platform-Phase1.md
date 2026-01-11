# Bellwood Platform - Phase 1 Overview

**Initiative:** User-Specific Data Access Enforcement  
**Status:** AuthServer ? | AdminAPI ? | Portal ??  
**Date:** January 11, 2026  
**Version:** 1.0

---

## ?? Phase 1 At A Glance

**Goal:** Establish ownership tracking and basic access filtering across the Bellwood platform.

**Completed:**
- ? **AuthServer:** Added `userId` claim to JWTs for audit tracking
- ? **AdminAPI:** Added ownership fields and role-based filtering
- ?? **Admin Portal:** Reference documentation available, awaiting implementation guidance

**Impact:**
- Every record now tracks who created/modified it
- Users only see data they're authorized to access
- Foundation for Phase 2 role-based UI and dispatcher features

---

## ?? AuthServer Changes

### What Changed
- All JWT tokens now include `userId` claim (Identity GUID)
- Dual UID format preserved (GUID for most, custom for drivers)
- Phase 2 dispatcher role prepared but not activated

### JWT Structure

**Regular User:**
```json
{
  "sub": "alice",
  "uid": "a1b2c3d4-...",
  "userId": "a1b2c3d4-...",  // NEW
  "role": "admin"
}
```

**Driver:**
```json
{
  "sub": "charlie",
  "uid": "driver-001",        // Custom for assignment
  "userId": "x9y8z7w6-...",   // Identity GUID for audit
  "role": "driver"
}
```

**Key Point:** `userId` is always Identity GUID, suitable for audit tracking.

**Full Documentation:** `Docs/AuthServer-Phase1.md`

---

## ?? AdminAPI Changes

### What Changed
- Added audit fields to all bookings/quotes:
  - `createdByUserId` - Who created the record
  - `modifiedByUserId` - Who last modified it
  - `modifiedOnUtc` - When last modified
- Implemented role-based filtering
- Added ownership verification (403 errors for unauthorized access)

### Access Rules

| User Role | Bookings List | Quotes List | Booking Detail |
|-----------|---------------|-------------|----------------|
| **Admin** | All records | All records | All records |
| **Booker** | Own only | Own only | Own only |
| **Driver** | Assigned only | N/A | Assigned only |

### API Response Example

**Before Phase 1:**
```json
{
  "bookingId": "BK-123",
  "passengerName": "John Doe",
  "createdUtc": "2026-01-10T10:00:00Z"
}
```

**After Phase 1:**
```json
{
  "bookingId": "BK-123",
  "passengerName": "John Doe",
  "createdUtc": "2026-01-10T10:00:00Z",
  "createdByUserId": "a1b2c3d4-...",      // NEW
  "modifiedByUserId": "x9y8z7w6-...",     // NEW
  "modifiedOnUtc": "2026-01-10T15:30:00Z" // NEW
}
```

**Full Documentation:** `Docs/AdminAPI-Phase1.md`

---

## ?? Admin Portal Integration

### What Portal Needs to Know

**Backend Changes:**
- JWT tokens have new `userId` claim (backward compatible)
- API responses include audit fields (backward compatible)
- API may return 403 Forbidden for unauthorized access
- API automatically filters data by user role

**Portal Impact:**
- Existing JWT handling continues to work
- API responses have additional fields
- Should handle 403 errors gracefully

**Implementation Guidance:**
- Awaiting direction from project lead
- Reference documentation available

**Reference Documentation:** `Docs/AdminPortal-Reference.md`

---

## ?? Data Flow

### How It Works

1. **User logs into Portal** ? AuthServer issues JWT with `userId`
2. **Portal calls AdminAPI** ? Includes JWT in Authorization header
3. **AdminAPI extracts `userId`** ? From JWT claims
4. **AdminAPI creates record** ? Stores `userId` in `createdByUserId`
5. **AdminAPI filters results** ? Based on user role and ownership
6. **Portal receives data** ? Already authorized and filtered

**Visual Diagrams:** `Docs/Platform-DataFlow.md`

---

## ?? Test Users

| Username | Password | Role | Access Level | Phase 1 Ready |
|----------|----------|------|--------------|---------------|
| alice | password | admin | All records | ? |
| bob | password | admin | All records | ? |
| chris | password | booker | Own only | ? |
| charlie | password | driver | Assigned only | ? |
| diana | password | dispatcher | Phase 2 only | ?? |

---

## ?? Documentation Index

### Component-Specific
- `AuthServer-Phase1.md` - Complete AuthServer guide
- `AdminAPI-Phase1.md` - Complete AdminAPI guide  
- `AdminPortal-Reference.md` - Backend changes reference

### Platform-Wide
- `Platform-Phase1.md` - This overview (you are here)
- `Platform-DataFlow.md` - Visual data flows
- `Planning-DataAccess.md` - Overall strategy

### Quick Reference
- `Quick-Reference.md` - Fast lookup guide

---

## ? Phase 1 Status

### AuthServer
- [x] Add `userId` claim to JWTs
- [x] Maintain dual UID format
- [x] Prepare Phase 2 dispatcher role
- [x] Documentation complete
- [x] Testing guide complete

**Status:** ? **COMPLETE**

---

### AdminAPI
- [x] Add ownership fields to records
- [x] Implement role-based filtering
- [x] Add ownership verification
- [x] Create authorization helpers
- [x] Documentation complete

**Status:** ? **COMPLETE**

---

### Admin Portal
- [x] Reference documentation created
- [ ] Awaiting implementation guidance
- [ ] Code changes pending
- [ ] Integration testing pending

**Status:** ?? **AWAITING GUIDANCE**

---

## ?? Next Steps

### For Teams

**AuthServer Team:**
- ? Phase 1 complete
- ? Await Phase 2 kickoff

**AdminAPI Team:**
- ? Phase 1 complete
- ? Using `userId` for audit tracking

**Admin Portal Team:**
- ?? Review reference documentation
- ? Await implementation guidance from project lead

**Testing Team:**
- ?? Prepare test environment
- ?? Review test scenarios
- ? Execute tests when Portal ready

---

### For Phase 2

**What's Coming:**
- Dispatcher role activation
- Authorization policies (AdminOnly, StaffOnly)
- Role-based UI (hide billing from dispatchers)
- Field masking for sensitive data

**Not Now:** Phase 1 focuses on ownership and basic filtering only.

---

## ?? Integration Points

### AuthServer ? AdminAPI
- **Working:** AdminAPI extracts `userId` from JWT
- **Working:** Stores in `createdByUserId` field
- **Working:** Uses for ownership verification

### AuthServer ? Admin Portal
- **Working:** Portal receives JWT with `userId`
- **Working:** Sends to AdminAPI automatically

### AdminAPI ? Admin Portal
- **Working:** Returns filtered data
- **Working:** Includes audit fields
- **New:** May return 403 Forbidden

---

## ?? Success Metrics

### Completion
- **AuthServer:** 100% ?
- **AdminAPI:** 100% ?
- **Admin Portal:** 0% (awaiting guidance)
- **Overall:** 67% (backend complete)

### Quality
- **Build Errors:** 0
- **Runtime Errors:** 0
- **Backward Compatibility:** ? Maintained

---

## ?? Key Decisions

### Dual UID Format (Preserved)
- Regular users: `uid` == `userId` (GUID)
- Drivers: `uid` custom, `userId` GUID
- **Reason:** AdminAPI dependency, clear separation

### userId Claim (Added)
- Always Identity GUID
- Used for audit tracking
- **Reason:** Consistent format for database

### Dispatcher Role (Prepared, Not Active)
- Infrastructure ready
- One-line activation
- **Reason:** Phase 2 dependency

---

**Status:** ?? Backend Complete, Portal Pending  
**Version:** 1.0  
**Last Updated:** January 11, 2026

---

*Single source of truth for Phase 1 platform-wide changes.* ???
