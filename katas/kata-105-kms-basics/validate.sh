#!/bin/bash

# ==============================================================================
# CloudKata Validator — kata-105
# KMS Basics: Keys, Aliases & Rotation
# ==============================================================================

ALIAS_NAME="alias/kata-105-key"

PASS=0
FAIL=0

pass() { echo "✅ PASS — $1"; ((PASS++)); }
fail() { echo "❌ FAIL — $1"; ((FAIL++)); }

echo ""
echo "=================================================="
echo " CloudKata Validator — kata-105"
echo " KMS Basics: Keys, Aliases & Rotation"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Check 1 — Alias exists (hard gate)
# ------------------------------------------------------------------------------
echo "Checking alias..."
ALIAS_JSON=$(aws kms list-aliases \
  --query "Aliases[?AliasName=='${ALIAS_NAME}'] | [0]" \
  --output json 2>/dev/null)

KEY_ID=$(echo "$ALIAS_JSON" | jq -r '.TargetKeyId // empty')

if [ -z "$KEY_ID" ] || [ "$KEY_ID" = "null" ]; then
  echo "❌ FAIL — Alias '$ALIAS_NAME' not found. Cannot continue."
  echo ""
  echo "  Make sure the alias is named exactly: $ALIAS_NAME"
  echo ""
  echo "=================================================="
  echo " Results: 0/7 checks passed (0%)"
  echo "=================================================="
  exit 1
fi
pass "Alias '$ALIAS_NAME' exists"

# ------------------------------------------------------------------------------
# Retrieve key metadata
# ------------------------------------------------------------------------------
KEY_METADATA=$(aws kms describe-key \
  --key-id "$KEY_ID" \
  --query 'KeyMetadata' \
  --output json 2>/dev/null)

if [ -z "$KEY_METADATA" ]; then
  echo "❌ FAIL — Could not retrieve metadata for key '$KEY_ID'. Cannot continue."
  echo ""
  echo "=================================================="
  echo " Results: 1/7 checks passed (14%)"
  echo "=================================================="
  exit 1
fi

# ------------------------------------------------------------------------------
# Check 2 — Key is a customer managed key (not AWS managed)
# ------------------------------------------------------------------------------
echo "Checking key manager..."
KEY_MANAGER=$(echo "$KEY_METADATA" | jq -r '.KeyManager')

if [ "$KEY_MANAGER" = "CUSTOMER" ]; then
  pass "Key is a customer managed key"
else
  fail "Key manager is '$KEY_MANAGER' — must be a customer managed key (CUSTOMER)"
fi

# ------------------------------------------------------------------------------
# Check 3 — Key spec is SYMMETRIC_DEFAULT
# ------------------------------------------------------------------------------
echo "Checking key spec..."
KEY_SPEC=$(echo "$KEY_METADATA" | jq -r '.KeySpec')

if [ "$KEY_SPEC" = "SYMMETRIC_DEFAULT" ]; then
  pass "Key spec is SYMMETRIC_DEFAULT"
else
  fail "Key spec is '$KEY_SPEC' — must be SYMMETRIC_DEFAULT"
fi

# ------------------------------------------------------------------------------
# Check 4 — Key usage is ENCRYPT_DECRYPT
# ------------------------------------------------------------------------------
echo "Checking key usage..."
KEY_USAGE=$(echo "$KEY_METADATA" | jq -r '.KeyUsage')

if [ "$KEY_USAGE" = "ENCRYPT_DECRYPT" ]; then
  pass "Key usage is ENCRYPT_DECRYPT"
else
  fail "Key usage is '$KEY_USAGE' — must be ENCRYPT_DECRYPT"
fi

# ------------------------------------------------------------------------------
# Check 5 — Key is enabled
# ------------------------------------------------------------------------------
echo "Checking key state..."
KEY_STATE=$(echo "$KEY_METADATA" | jq -r '.KeyState')

if [ "$KEY_STATE" = "Enabled" ]; then
  pass "Key is enabled"
else
  fail "Key state is '$KEY_STATE' — must be Enabled"
fi

# ------------------------------------------------------------------------------
# Check 6 — Automatic key rotation is enabled
# ------------------------------------------------------------------------------
echo "Checking key rotation..."
ROTATION_STATUS=$(aws kms get-key-rotation-status \
  --key-id "$KEY_ID" \
  --query 'KeyRotationEnabled' \
  --output text 2>/dev/null | tr '[:upper:]' '[:lower:]')

if [ "$ROTATION_STATUS" = "true" ]; then
  pass "Automatic key rotation is enabled"
else
  fail "Automatic key rotation is not enabled — found: '${ROTATION_STATUS}'"
fi

# ------------------------------------------------------------------------------
# Check 7 — Required tags are present
# ------------------------------------------------------------------------------
echo "Checking tags..."
TAGS_JSON=$(aws kms list-resource-tags \
  --key-id "$KEY_ID" \
  --query 'Tags' \
  --output json 2>/dev/null)

PROJECT_TAG=$(echo "$TAGS_JSON" | \
  jq -r '.[] | select(.TagKey == "Project") | .TagValue' 2>/dev/null)
KATA_TAG=$(echo "$TAGS_JSON" | \
  jq -r '.[] | select(.TagKey == "Kata") | .TagValue' 2>/dev/null)

if [ "$PROJECT_TAG" = "CloudKata" ] && [ "$KATA_TAG" = "kata-105" ]; then
  pass "Required tags are present (Project: CloudKata, Kata: kata-105)"
else
  MISSING=""
  [ "$PROJECT_TAG" != "CloudKata" ] && MISSING="Project: CloudKata "
  [ "$KATA_TAG" != "kata-105" ] && MISSING="${MISSING}Kata: kata-105"
  fail "Missing or incorrect tags: $MISSING"
fi

# ------------------------------------------------------------------------------
# Results
# ------------------------------------------------------------------------------
PCT=$(( (PASS * 100) / 7 ))

echo ""
echo "=================================================="
echo " Results: $PASS/7 checks passed ($PCT%)"
echo "=================================================="

if [ "$PASS" -eq 7 ]; then
  echo " 🎉 Perfect score! All kata-105 requirements met."
elif [ "$PASS" -ge 5 ]; then
  echo " 🔧 Almost there — review the failed checks above."
else
  echo " 📖 Keep going — consult HINTS.md for guidance."
fi
echo ""