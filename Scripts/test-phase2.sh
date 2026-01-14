# AuthServer Phase 2 - Test Script
# Tests all Phase 2 functionality: dispatcher role, policies, role assignment
# Run with: bash test-phase2.sh

# Configuration
AUTHSERVER_URL="https://localhost:5001"
ADMIN_USER="alice"
ADMIN_PASS="password"
DISPATCHER_USER="diana"
DISPATCHER_PASS="password"
TEST_USER="bob"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
print_test() {
    echo -e "\n${YELLOW}???????????????????????????????????????????????????????${NC}"
    echo -e "${YELLOW}TEST $1: $2${NC}"
    echo -e "${YELLOW}???????????????????????????????????????????????????????${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
}

print_pass() {
    echo -e "${GREEN}? PASS: $1${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_fail() {
    echo -e "${RED}? FAIL: $1${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_info() {
    echo -e "? INFO: $1"
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed. Please install jq to run this script.${NC}"
    echo "Install with: brew install jq (Mac) or apt-get install jq (Linux)"
    exit 1
fi

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed.${NC}"
    exit 1
fi

echo "??????????????????????????????????????????????????????????????"
echo "?         AuthServer Phase 2 - Functional Tests             ?"
echo "??????????????????????????????????????????????????????????????"
echo ""
echo "Server: $AUTHSERVER_URL"
echo "Date: $(date)"
echo ""

# ============================================================================
# TEST 1: Dispatcher Role - Login
# ============================================================================
print_test "1" "Dispatcher Login"

RESPONSE=$(curl -s -X POST "$AUTHSERVER_URL/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$DISPATCHER_USER\",\"password\":\"$DISPATCHER_PASS\"}" \
  -w "\n%{http_code}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    DISPATCHER_TOKEN=$(echo "$BODY" | jq -r '.token')
    
    # Decode JWT (base64 decode the payload)
    PAYLOAD=$(echo "$DISPATCHER_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null || echo "$DISPATCHER_TOKEN" | cut -d'.' -f2 | base64 -D 2>/dev/null)
    ROLE=$(echo "$PAYLOAD" | jq -r '.role')
    EMAIL=$(echo "$PAYLOAD" | jq -r '.email')
    
    if [ "$ROLE" = "dispatcher" ]; then
        print_pass "Dispatcher login successful, role claim is 'dispatcher'"
        print_info "Email claim: $EMAIL"
    else
        print_fail "Expected role 'dispatcher', got '$ROLE'"
    fi
else
    print_fail "Login failed with HTTP $HTTP_CODE"
    echo "Response: $BODY"
fi

# ============================================================================
# TEST 2: Admin Login
# ============================================================================
print_test "2" "Admin Login"

RESPONSE=$(curl -s -X POST "$AUTHSERVER_URL/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$ADMIN_USER\",\"password\":\"$ADMIN_PASS\"}" \
  -w "\n%{http_code}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    ADMIN_TOKEN=$(echo "$BODY" | jq -r '.token')
    
    PAYLOAD=$(echo "$ADMIN_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null || echo "$ADMIN_TOKEN" | cut -d'.' -f2 | base64 -D 2>/dev/null)
    ROLE=$(echo "$PAYLOAD" | jq -r '.role')
    
    if [ "$ROLE" = "admin" ]; then
        print_pass "Admin login successful, role claim is 'admin'"
    else
        print_fail "Expected role 'admin', got '$ROLE'"
    fi
else
    print_fail "Login failed with HTTP $HTTP_CODE"
fi

# ============================================================================
# TEST 3: Dispatcher Cannot Access Admin Endpoints
# ============================================================================
print_test "3" "Dispatcher Denied Admin Access (AdminOnly Policy)"

RESPONSE=$(curl -s -X GET "$AUTHSERVER_URL/api/admin/users/drivers" \
  -H "Authorization: Bearer $DISPATCHER_TOKEN" \
  -w "\n%{http_code}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "403" ]; then
    print_pass "Dispatcher correctly denied access (403 Forbidden)"
elif [ "$HTTP_CODE" = "401" ]; then
    print_pass "Dispatcher correctly denied access (401 Unauthorized)"
else
    print_fail "Expected 403 or 401, got HTTP $HTTP_CODE"
    BODY=$(echo "$RESPONSE" | sed '$d')
    echo "Response: $BODY"
fi

# ============================================================================
# TEST 4: Admin Can Access Admin Endpoints
# ============================================================================
print_test "4" "Admin Can Access Admin Endpoints"

RESPONSE=$(curl -s -X GET "$AUTHSERVER_URL/api/admin/users/drivers" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -w "\n%{http_code}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    DRIVER_COUNT=$(echo "$BODY" | jq 'length')
    print_pass "Admin can access admin endpoints (200 OK)"
    print_info "Found $DRIVER_COUNT driver users"
else
    print_fail "Expected 200, got HTTP $HTTP_CODE"
    echo "Response: $BODY"
fi

# ============================================================================
# TEST 5: Role Assignment - Change User to Dispatcher
# ============================================================================
print_test "5" "Role Assignment - Promote User to Dispatcher"

RESPONSE=$(curl -s -X PUT "$AUTHSERVER_URL/api/admin/users/$TEST_USER/role" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"role":"dispatcher"}' \
  -w "\n%{http_code}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    NEW_ROLE=$(echo "$BODY" | jq -r '.newRole')
    PREV_ROLES=$(echo "$BODY" | jq -r '.previousRoles[]' | tr '\n' ', ' | sed 's/,$//')
    
    if [ "$NEW_ROLE" = "dispatcher" ]; then
        print_pass "Successfully changed $TEST_USER to dispatcher"
        print_info "Previous roles: $PREV_ROLES"
        print_info "New role: $NEW_ROLE"
    else
        print_fail "Expected new role 'dispatcher', got '$NEW_ROLE'"
    fi
else
    print_fail "Role assignment failed with HTTP $HTTP_CODE"
    echo "Response: $BODY"
fi

# ============================================================================
# TEST 6: Verify User Has New Role
# ============================================================================
print_test "6" "Verify User Has New Role (Re-login)"

RESPONSE=$(curl -s -X POST "$AUTHSERVER_URL/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$TEST_USER\",\"password\":\"$ADMIN_PASS\"}" \
  -w "\n%{http_code}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    BOB_TOKEN=$(echo "$BODY" | jq -r '.token')
    
    PAYLOAD=$(echo "$BOB_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null || echo "$BOB_TOKEN" | cut -d'.' -f2 | base64 -D 2>/dev/null)
    ROLE=$(echo "$PAYLOAD" | jq -r '.role')
    
    if [ "$ROLE" = "dispatcher" ]; then
        print_pass "$TEST_USER now has 'dispatcher' role in JWT"
    else
        print_fail "Expected role 'dispatcher', got '$ROLE'"
    fi
else
    print_fail "Login failed with HTTP $HTTP_CODE"
fi

# ============================================================================
# TEST 7: New Dispatcher Cannot Access Admin Endpoints
# ============================================================================
print_test "7" "New Dispatcher Cannot Access Admin Endpoints"

RESPONSE=$(curl -s -X GET "$AUTHSERVER_URL/api/admin/users/drivers" \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -w "\n%{http_code}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "403" ] || [ "$HTTP_CODE" = "401" ]; then
    print_pass "$TEST_USER (now dispatcher) correctly denied admin access"
else
    print_fail "Expected 403 or 401, got HTTP $HTTP_CODE"
fi

# ============================================================================
# TEST 8: Dispatcher Cannot Assign Roles
# ============================================================================
print_test "8" "Dispatcher Cannot Assign Roles"

RESPONSE=$(curl -s -X PUT "$AUTHSERVER_URL/api/admin/users/charlie/role" \
  -H "Authorization: Bearer $DISPATCHER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"role":"admin"}' \
  -w "\n%{http_code}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "403" ] || [ "$HTTP_CODE" = "401" ]; then
    print_pass "Dispatcher correctly denied role assignment capability"
else
    print_fail "Expected 403 or 401, got HTTP $HTTP_CODE"
    BODY=$(echo "$RESPONSE" | sed '$d')
    echo "Response: $BODY"
fi

# ============================================================================
# TEST 9: Role Assignment Validation (Invalid Role)
# ============================================================================
print_test "9" "Role Assignment Validation - Invalid Role"

RESPONSE=$(curl -s -X PUT "$AUTHSERVER_URL/api/admin/users/$TEST_USER/role" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"role":"invalidrole"}' \
  -w "\n%{http_code}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "400" ]; then
    print_pass "Invalid role correctly rejected (400 Bad Request)"
    ERROR_MSG=$(echo "$BODY" | jq -r '.error')
    print_info "Error: $ERROR_MSG"
else
    print_fail "Expected 400, got HTTP $HTTP_CODE"
fi

# ============================================================================
# TEST 10: Restore Admin Role
# ============================================================================
print_test "10" "Restore User to Admin Role"

RESPONSE=$(curl -s -X PUT "$AUTHSERVER_URL/api/admin/users/$TEST_USER/role" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"role":"admin"}' \
  -w "\n%{http_code}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    NEW_ROLE=$(echo "$BODY" | jq -r '.newRole')
    
    if [ "$NEW_ROLE" = "admin" ]; then
        print_pass "Successfully restored $TEST_USER to admin role"
    else
        print_fail "Expected new role 'admin', got '$NEW_ROLE'"
    fi
else
    print_fail "Role restoration failed with HTTP $HTTP_CODE"
    echo "Response: $BODY"
fi

# ============================================================================
# TEST 11: User Diagnostic Endpoint
# ============================================================================
print_test "11" "User Diagnostic Endpoint - Check Dispatcher Info"

RESPONSE=$(curl -s -X GET "$AUTHSERVER_URL/dev/user-info/$DISPATCHER_USER" \
  -w "\n%{http_code}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    USERNAME=$(echo "$BODY" | jq -r '.username')
    ROLES=$(echo "$BODY" | jq -r '.roles[]' | tr '\n' ', ' | sed 's/,$//')
    HAS_EMAIL=$(echo "$BODY" | jq -r '.diagnostics.hasEmail')
    
    if [ "$USERNAME" = "$DISPATCHER_USER" ] && [ "$ROLES" = "dispatcher" ]; then
        print_pass "Diagnostic endpoint works, dispatcher info correct"
        print_info "Roles: $ROLES"
        print_info "Has email: $HAS_EMAIL"
    else
        print_fail "Unexpected diagnostic response"
    fi
else
    print_fail "Diagnostic endpoint failed with HTTP $HTTP_CODE"
fi

# ============================================================================
# TEST 12: Health Check
# ============================================================================
print_test "12" "Health Check Endpoint"

RESPONSE=$(curl -s -X GET "$AUTHSERVER_URL/health" \
  -w "\n%{http_code}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] && [ "$BODY" = "ok" ]; then
    print_pass "Health check endpoint responding correctly"
else
    print_fail "Health check failed"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "??????????????????????????????????????????????????????????????"
echo "?                    TEST SUMMARY                            ?"
echo "??????????????????????????????????????????????????????????????"
echo ""
echo "Tests Run:    $TESTS_RUN"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}??????????????????????????????????????????????????????????????${NC}"
    echo -e "${GREEN}?           ? ALL TESTS PASSED - PHASE 2 READY!             ?${NC}"
    echo -e "${GREEN}??????????????????????????????????????????????????????????????${NC}"
    exit 0
else
    echo -e "${RED}??????????????????????????????????????????????????????????????${NC}"
    echo -e "${RED}?             ? SOME TESTS FAILED - SEE ABOVE                ?${NC}"
    echo -e "${RED}??????????????????????????????????????????????????????????????${NC}"
    exit 1
fi
