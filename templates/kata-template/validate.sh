#!/bin/bash
# =============================================================================
# CloudKata — kata-XXX Validator
# kata:    kata-XXX
# title:   Your Kata Title
# author:  Your Name
# github:  https://github.com/yourusername
# =============================================================================
#
# Run this script in AWS CloudShell after building your kata infrastructure.
#
# Usage:
#   chmod +x validate.sh
#   ./validate.sh
#
# =============================================================================

PASS=0
FAIL=0
TOTAL=0

# ------------------------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------------------------
pass() {
  echo "✅ PASS — $1"
  PASS=$((PASS + 1))
  TOTAL=$((TOTAL + 1))
}

fail() {
  echo "❌ FAIL — $1: $2"
  FAIL=$((FAIL + 1))
  TOTAL=$((TOTAL + 1))
}

# ------------------------------------------------------------------------------
# Header
# ------------------------------------------------------------------------------
echo ""
echo "=================================================="
echo " CloudKata Validator — kata-XXX"
echo " Your Kata Title"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Check 1 — [Short description of what you are checking]
# ------------------------------------------------------------------------------
# Replace the AWS CLI command below with the appropriate check.
# Use 2>/dev/null to suppress errors for missing resources.
# Use || echo "NOT_FOUND" to handle missing resources gracefully.
# ------------------------------------------------------------------------------
RESULT=$(aws some-service describe-something \
  --name "kata-XXX-ResourceName" \
  --query 'SomeField' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$RESULT" != "NOT_FOUND" ] && [ -n "$RESULT" ]; then
  pass "kata-XXX-ResourceName exists and is configured correctly"
else
  fail "kata-XXX-ResourceName" "Resource not found — ensure it exists with the correct name and configuration"
fi

# ------------------------------------------------------------------------------
# Check 2 — [Short description of what you are checking]
# ------------------------------------------------------------------------------
RESULT=$(aws some-service describe-something \
  --name "kata-XXX-AnotherResource" \
  --query 'SomeField' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$RESULT" != "NOT_FOUND" ] && [ -n "$RESULT" ]; then
  pass "kata-XXX-AnotherResource exists and is configured correctly"
else
  fail "kata-XXX-AnotherResource" "Resource not found — ensure it exists with the correct name and configuration"
fi

# ------------------------------------------------------------------------------
# Check 3 — [Short description of what you are checking]
# ------------------------------------------------------------------------------
# Example of a deeper configuration check — checking a specific field value
# ------------------------------------------------------------------------------
EXPECTED="ExpectedValue"
ACTUAL=$(aws some-service describe-something \
  --name "kata-XXX-ResourceName" \
  --query 'SomeConfigField' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$ACTUAL" = "$EXPECTED" ]; then
  pass "kata-XXX-ResourceName is configured with the correct value"
else
  fail "kata-XXX-ResourceName configuration" "Expected '$EXPECTED' but got '$ACTUAL' — check your configuration"
fi

# ------------------------------------------------------------------------------
# Add additional checks following the same pattern.
# Each check should be independent — a failure in one check must not prevent
# subsequent checks from running.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo ""
echo "=================================================="
if [ "$TOTAL" -gt 0 ]; then
  PERCENTAGE=$(( PASS * 100 / TOTAL ))
else
  PERCENTAGE=0
fi
echo " Results: $PASS/$TOTAL checks passed ($PERCENTAGE%)"
echo "=================================================="
echo ""

if [ "$PERCENTAGE" -eq 100 ]; then
  echo " 🎉 Perfect score! All requirements met."
  echo ""
fi

if [ "$FAIL" -gt 0 ]; then
  echo " Review the failed checks above, fix your infrastructure,"
  echo " and re-run this validator."
  echo ""
  exit 1
fi