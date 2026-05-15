#!/bin/bash

# ==============================================================================
# CloudKata Validator — kata-109
# SSM Parameter Store: Parameters, Types & Versioning
# ==============================================================================

PARAM_ENV="/kata-109/config/environment"
PARAM_KEY="/kata-109/config/api-key"
EXPECTED_ENV_VALUE="staging"
EXPECTED_KEY_VALUE="supersecret"
EXPECTED_ENV_TYPE="String"
EXPECTED_KEY_TYPE="SecureString"
TOTAL_CHECKS=8

PASS=0
FAIL=0

pass() { echo "✅ PASS — $1"; ((PASS++)); }
fail() { echo "❌ FAIL — $1"; ((FAIL++)); }

echo ""
echo "=================================================="
echo " CloudKata Validator — kata-109"
echo " SSM Parameter Store: Parameters, Types & Versioning"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Check 1 — String parameter exists (hard gate for checks 2-4)
# ------------------------------------------------------------------------------
echo "Checking parameter '$PARAM_ENV'..."
ENV_JSON=$(aws ssm get-parameter \
  --name "$PARAM_ENV" \
  --output json 2>/dev/null)

if [ -z "$ENV_JSON" ] || [ "$ENV_JSON" = "null" ]; then
  fail "Parameter '$PARAM_ENV' not found"
  fail "Parameter type could not be checked — parameter not found"
  fail "Parameter value could not be checked — parameter not found"
  fail "Parameter version could not be checked — parameter not found"
else
  pass "Parameter '$PARAM_ENV' exists"

  ENV_TYPE=$(echo "$ENV_JSON" | jq -r '.Parameter.Type // empty')
  ENV_VALUE=$(echo "$ENV_JSON" | jq -r '.Parameter.Value // empty')
  ENV_VERSION=$(echo "$ENV_JSON" | jq -r '.Parameter.Version // 0')

  # ----------------------------------------------------------------------------
  # Check 2 — String parameter type is String
  # ----------------------------------------------------------------------------
  if [ "$ENV_TYPE" = "$EXPECTED_ENV_TYPE" ]; then
    pass "Parameter type is String"
  else
    fail "Parameter type is '$ENV_TYPE' — expected '$EXPECTED_ENV_TYPE'"
  fi

  # ----------------------------------------------------------------------------
  # Check 3 — String parameter value is 'staging'
  # ----------------------------------------------------------------------------
  if [ "$ENV_VALUE" = "$EXPECTED_ENV_VALUE" ]; then
    pass "Parameter value is '$EXPECTED_ENV_VALUE'"
  else
    fail "Parameter value is '$ENV_VALUE' — expected '$EXPECTED_ENV_VALUE' (have you updated the parameter after creating it?)"
  fi

  # ----------------------------------------------------------------------------
  # Check 4 — String parameter version is 2 or higher
  # ----------------------------------------------------------------------------
  if [ "$ENV_VERSION" -ge 2 ] 2>/dev/null; then
    pass "Parameter version is $ENV_VERSION (version 2 or higher)"
  else
    fail "Parameter version is $ENV_VERSION — expected 2 or higher (update the parameter value to increment the version)"
  fi
fi

# ------------------------------------------------------------------------------
# Check 5 — SecureString parameter exists (hard gate for checks 6-7)
# ------------------------------------------------------------------------------
echo "Checking parameter '$PARAM_KEY'..."
KEY_JSON=$(aws ssm get-parameter \
  --name "$PARAM_KEY" \
  --with-decryption \
  --output json 2>/dev/null)

if [ -z "$KEY_JSON" ] || [ "$KEY_JSON" = "null" ]; then
  fail "Parameter '$PARAM_KEY' not found"
  fail "Parameter type could not be checked — parameter not found"
  fail "Parameter value could not be checked — parameter not found"
else
  pass "Parameter '$PARAM_KEY' exists"

  KEY_TYPE=$(echo "$KEY_JSON" | jq -r '.Parameter.Type // empty')
  KEY_VALUE=$(echo "$KEY_JSON" | jq -r '.Parameter.Value // empty')

  # ----------------------------------------------------------------------------
  # Check 6 — SecureString parameter type is SecureString
  # ----------------------------------------------------------------------------
  if [ "$KEY_TYPE" = "$EXPECTED_KEY_TYPE" ]; then
    pass "Parameter type is SecureString"
  else
    fail "Parameter type is '$KEY_TYPE' — expected '$EXPECTED_KEY_TYPE'"
  fi

  # ----------------------------------------------------------------------------
  # Check 7 — SecureString parameter value is 'supersecret'
  # ----------------------------------------------------------------------------
  if [ "$KEY_VALUE" = "$EXPECTED_KEY_VALUE" ]; then
    pass "Parameter value is '$EXPECTED_KEY_VALUE'"
  else
    fail "Parameter value is incorrect — expected '$EXPECTED_KEY_VALUE'"
  fi
fi

# ------------------------------------------------------------------------------
# Check 8 — Required tags on String parameter
#
# SSM list-tags-for-resource uses --resource-type Parameter and
# --resource-id <parameter-name> (not ARN). Returns {"TagList": [{Key, Value}]}
# — array format, requires jq select() pattern.
# ------------------------------------------------------------------------------
echo "Checking tags on '$PARAM_ENV'..."
ENV_TAGS=$(aws ssm list-tags-for-resource \
  --resource-type Parameter \
  --resource-id "$PARAM_ENV" \
  --output json 2>/dev/null)

ENV_PROJECT=$(echo "$ENV_TAGS" | jq -r '.TagList[] | select(.Key=="Project") | .Value' 2>/dev/null)
ENV_KATA=$(echo "$ENV_TAGS" | jq -r '.TagList[] | select(.Key=="Kata") | .Value' 2>/dev/null)

if [ "$ENV_PROJECT" = "CloudKata" ] && [ "$ENV_KATA" = "kata-109" ]; then
  pass "Required tags are present on '$PARAM_ENV'"
else
  MISSING=""
  [ "$ENV_PROJECT" != "CloudKata" ] && MISSING="Project: CloudKata "
  [ "$ENV_KATA" != "kata-109" ] && MISSING="${MISSING}Kata: kata-109"
  fail "Missing or incorrect tags on '$PARAM_ENV': $MISSING"
fi

# ------------------------------------------------------------------------------
# Results
# ------------------------------------------------------------------------------
PCT=$(( (PASS * 100) / TOTAL_CHECKS ))

echo ""
echo "=================================================="
echo " Results: $PASS/$TOTAL_CHECKS checks passed ($PCT%)"
echo "=================================================="

if [ "$PASS" -eq "$TOTAL_CHECKS" ]; then
  echo " 🎉 Perfect score! All kata-109 requirements met."
elif [ "$PASS" -ge 5 ]; then
  echo " 🔧 Almost there — review the failed checks above."
else
  echo " 📖 Keep going — consult HINTS.md for guidance."
fi
echo ""