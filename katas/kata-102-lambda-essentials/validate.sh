#!/bin/bash

# ==============================================================================
# CloudKata Validator — kata-102
# Lambda Essentials: Functions, Triggers & Environment Variables
# ==============================================================================

FUNCTION_NAME="kata-102-EnvironmentReader"
ROLE_NAME="kata-102-LambdaExecutionRole"
EXPECTED_RUNTIME="python3.12"
EXPECTED_ENV_KEY="APP_ENVIRONMENT"
EXPECTED_ENV_VALUE="production"
DEFAULT_TIMEOUT=3
DEFAULT_MEMORY=128

PASS=0
FAIL=0

pass() { echo "✅ PASS — $1"; ((PASS++)); }
fail() { echo "❌ FAIL — $1"; ((FAIL++)); }

echo ""
echo "=================================================="
echo " CloudKata Validator — kata-102"
echo " Lambda Essentials: Functions, Triggers & Environment Variables"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Check 1 — Function exists (hard gate)
# ------------------------------------------------------------------------------
echo "Checking function existence..."
FUNCTION_JSON=$(aws lambda get-function-configuration \
  --function-name "$FUNCTION_NAME" 2>/dev/null)

if [ -z "$FUNCTION_JSON" ]; then
  echo "❌ FAIL — Function '$FUNCTION_NAME' not found. Cannot continue."
  echo ""
  echo "=================================================="
  echo " Results: 0/9 checks passed (0%)"
  echo "=================================================="
  exit 1
fi
pass "Function '$FUNCTION_NAME' exists"

# ------------------------------------------------------------------------------
# Check 2 — Runtime is python3.12
# ------------------------------------------------------------------------------
echo "Checking runtime..."
RUNTIME=$(echo "$FUNCTION_JSON" | jq -r '.Runtime')
if [ "$RUNTIME" = "$EXPECTED_RUNTIME" ]; then
  pass "Runtime is $EXPECTED_RUNTIME"
else
  fail "Runtime is '$RUNTIME' — expected '$EXPECTED_RUNTIME'"
fi

# ------------------------------------------------------------------------------
# Check 3 — Handler is correctly configured
# ------------------------------------------------------------------------------
echo "Checking handler..."
HANDLER=$(echo "$FUNCTION_JSON" | jq -r '.Handler')
if echo "$HANDLER" | grep -q "lambda_handler"; then
  pass "Handler references 'lambda_handler' ($HANDLER)"
else
  fail "Handler '$HANDLER' does not reference 'lambda_handler'"
fi

# ------------------------------------------------------------------------------
# Check 4 — Execution role is attached
# ------------------------------------------------------------------------------
echo "Checking execution role..."
ROLE_ARN=$(echo "$FUNCTION_JSON" | jq -r '.Role')
if echo "$ROLE_ARN" | grep -q "$ROLE_NAME"; then
  pass "Execution role '$ROLE_NAME' is attached"
else
  fail "Execution role does not match '$ROLE_NAME' — found: $ROLE_ARN"
fi

# ------------------------------------------------------------------------------
# Check 5 — Environment variable APP_ENVIRONMENT is set to 'production'
# ------------------------------------------------------------------------------
echo "Checking environment variables..."
ENV_VALUE=$(echo "$FUNCTION_JSON" | \
  jq -r ".Environment.Variables.${EXPECTED_ENV_KEY} // \"__missing__\"")

if [ "$ENV_VALUE" = "$EXPECTED_ENV_VALUE" ]; then
  pass "Environment variable $EXPECTED_ENV_KEY is set to '$EXPECTED_ENV_VALUE'"
elif [ "$ENV_VALUE" = "__missing__" ]; then
  fail "Environment variable $EXPECTED_ENV_KEY is not set"
else
  fail "Environment variable $EXPECTED_ENV_KEY is '$ENV_VALUE' — expected '$EXPECTED_ENV_VALUE'"
fi

# ------------------------------------------------------------------------------
# Check 6 — Timeout is greater than default (3s)
# ------------------------------------------------------------------------------
echo "Checking timeout..."
TIMEOUT=$(echo "$FUNCTION_JSON" | jq -r '.Timeout')
if [ "$TIMEOUT" -gt "$DEFAULT_TIMEOUT" ] 2>/dev/null; then
  pass "Timeout is ${TIMEOUT}s (greater than default of ${DEFAULT_TIMEOUT}s)"
else
  fail "Timeout is ${TIMEOUT}s — must be greater than default of ${DEFAULT_TIMEOUT}s"
fi

# ------------------------------------------------------------------------------
# Check 7 — Memory is greater than default (128MB)
# ------------------------------------------------------------------------------
echo "Checking memory..."
MEMORY=$(echo "$FUNCTION_JSON" | jq -r '.MemorySize')
if [ "$MEMORY" -gt "$DEFAULT_MEMORY" ] 2>/dev/null; then
  pass "Memory is ${MEMORY}MB (greater than default of ${DEFAULT_MEMORY}MB)"
else
  fail "Memory is ${MEMORY}MB — must be greater than default of ${DEFAULT_MEMORY}MB"
fi

# ------------------------------------------------------------------------------
# Check 8 & 9 — Invoke function and validate response
# ------------------------------------------------------------------------------
echo "Invoking function..."
INVOKE_OUTPUT=$(mktemp)
HTTP_STATUS=$(aws lambda invoke \
  --function-name "$FUNCTION_NAME" \
  --payload '{}' \
  --cli-binary-format raw-in-base64-out \
  --query 'StatusCode' \
  --output text \
  "$INVOKE_OUTPUT" 2>/dev/null)

if [ "$HTTP_STATUS" != "200" ] || [ ! -s "$INVOKE_OUTPUT" ]; then
  fail "Function invocation failed — HTTP status: $HTTP_STATUS"
  fail "Invocation response could not be parsed"
  rm -f "$INVOKE_OUTPUT"
else
  RESPONSE=$(cat "$INVOKE_OUTPUT")
  rm -f "$INVOKE_OUTPUT"

  # Check 8 — statusCode is 200
  STATUS_CODE=$(echo "$RESPONSE" | jq -r '.statusCode' 2>/dev/null)
  if [ "$STATUS_CODE" = "200" ]; then
    pass "Function invocation returns statusCode 200"
  else
    fail "Function returned statusCode '$STATUS_CODE' — expected 200"
  fi

  # Check 9 — environment value in response body matches expected
  BODY_ENV=$(echo "$RESPONSE" | jq -r '.body | fromjson | .environment' 2>/dev/null)
  if [ "$BODY_ENV" = "$EXPECTED_ENV_VALUE" ]; then
    pass "Invocation response contains correct environment value '$EXPECTED_ENV_VALUE'"
  else
    fail "Response environment value is '$BODY_ENV' — expected '$EXPECTED_ENV_VALUE'"
  fi
fi

# ------------------------------------------------------------------------------
# Results
# ------------------------------------------------------------------------------
TOTAL=$((PASS + FAIL))
PCT=$(( (PASS * 100) / 9 ))

echo ""
echo "=================================================="
echo " Results: $PASS/9 checks passed ($PCT%)"
echo "=================================================="

if [ "$PASS" -eq 9 ]; then
  echo " 🎉 Perfect score! All kata-102 requirements met."
elif [ "$PASS" -ge 6 ]; then
  echo " 🔧 Almost there — review the failed checks above."
else
  echo " 📖 Keep going — consult HINTS.md for guidance."
fi
echo ""