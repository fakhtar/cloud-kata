#!/bin/bash
# =============================================================================
# CloudKata — kata-204 Validator
# kata:    kata-204
# title:   S3 + Lambda: Event Notifications & Triggers
# author:  Faisal Akhtar
# github:  https://github.com/fakhtar
# =============================================================================
#
# Run this script in AWS CloudShell after building your kata infrastructure.
#
# Usage:
#   sed -i 's/\r//' validate.sh
#   chmod +x validate.sh
#   ./validate.sh
#
# =============================================================================

PASS=0
FAIL=0
TOTAL=0

BUCKET_PREFIX="kata-204-bucket-"
FUNCTION_NAME="kata-204-ProcessorFunction"
EXPECTED_RUNTIME="python3.12"

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
echo " CloudKata Validator — kata-204"
echo " S3 + Lambda: Event Notifications & Triggers"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Check 1 — Bucket with prefix exists (hard gate for checks 3, 4, 6, 7)
# ------------------------------------------------------------------------------
echo "Checking for bucket with prefix '${BUCKET_PREFIX}'..."
BUCKET_NAME=$(aws s3api list-buckets \
  --query "Buckets[?starts_with(Name, '${BUCKET_PREFIX}')].Name | [0]" \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$BUCKET_NAME" != "NOT_FOUND" ] && [ "$BUCKET_NAME" != "None" ] && [ -n "$BUCKET_NAME" ]; then
  pass "Bucket with prefix '${BUCKET_PREFIX}' exists (${BUCKET_NAME})"
else
  fail "Bucket discovery" "No bucket found starting with '${BUCKET_PREFIX}' — ensure the bucket exists with this exact prefix"
  echo ""
  echo "  Cannot continue without a valid bucket. Please create the bucket and re-run."
  echo ""
  echo "=================================================="
  echo " Results: 0/$((TOTAL)) checks passed (0%)"
  echo "=================================================="
  exit 1
fi

# ------------------------------------------------------------------------------
# Check 2 — Lambda function exists with the correct runtime (hard gate for 4, 6, 7)
# ------------------------------------------------------------------------------
echo "Checking Lambda function '${FUNCTION_NAME}'..."
FUNCTION_JSON=$(aws lambda get-function \
  --function-name "$FUNCTION_NAME" \
  --output json 2>/dev/null)

if [ -z "$FUNCTION_JSON" ] || [ "$FUNCTION_JSON" = "null" ]; then
  fail "Lambda function '${FUNCTION_NAME}'" "Function not found — ensure a function named exactly '${FUNCTION_NAME}' exists"
  fail "Lambda runtime" "Could not check — function not found"
else
  pass "Lambda function '${FUNCTION_NAME}' exists"

  RUNTIME=$(echo "$FUNCTION_JSON" | jq -r '.Configuration.Runtime // empty')

  # ----------------------------------------------------------------------------
  # Check 3 — Runtime is python3.12
  # ----------------------------------------------------------------------------
  if [ "$RUNTIME" = "$EXPECTED_RUNTIME" ]; then
    pass "Lambda runtime is ${EXPECTED_RUNTIME}"
  else
    fail "Lambda runtime" "Found '${RUNTIME}' but expected '${EXPECTED_RUNTIME}'"
  fi
fi

# ------------------------------------------------------------------------------
# Check 4 — S3 event notification configured for s3:ObjectCreated:* targeting
#           the function (hard gate informs but does not block checks 5+)
# ------------------------------------------------------------------------------
echo "Checking S3 event notification configuration on '${BUCKET_NAME}'..."
NOTIFICATION_JSON=$(aws s3api get-bucket-notification-configuration \
  --bucket "$BUCKET_NAME" \
  --output json 2>/dev/null)

LAMBDA_CONFIGS=$(echo "$NOTIFICATION_JSON" | jq -c '.LambdaFunctionConfigurations // []' 2>/dev/null)
MATCHING_CONFIG=$(echo "$LAMBDA_CONFIGS" | jq -c --arg fn "$FUNCTION_NAME" \
  '[.[] | select(.LambdaFunctionArn != null and (.LambdaFunctionArn | endswith($fn)))] | .[0]' 2>/dev/null)

if [ "$MATCHING_CONFIG" != "null" ] && [ -n "$MATCHING_CONFIG" ] && [ "$MATCHING_CONFIG" != "[]" ]; then
  EVENTS=$(echo "$MATCHING_CONFIG" | jq -r '.Events // [] | join(",")' 2>/dev/null)
  HAS_OBJECT_CREATED=$(echo "$MATCHING_CONFIG" | jq -r \
    '[.Events // [] | .[] | select(startswith("s3:ObjectCreated"))] | length' 2>/dev/null)

  if [ "$HAS_OBJECT_CREATED" -ge 1 ] 2>/dev/null; then
    pass "S3 event notification configured for s3:ObjectCreated events (${EVENTS})"
  else
    fail "S3 event notification" "Notification found targeting the function, but no s3:ObjectCreated event type configured (found: ${EVENTS:-none})"
  fi

  # ----------------------------------------------------------------------------
  # Check 5 — Notification targets the correct function
  # (folded into Check 4's matching logic — confirmed by MATCHING_CONFIG itself)
  # ----------------------------------------------------------------------------
  pass "Notification targets '${FUNCTION_NAME}'"
else
  fail "S3 event notification" "No LambdaFunctionConfigurations entry found targeting '${FUNCTION_NAME}' on bucket '${BUCKET_NAME}'"
  fail "Notification target" "Cannot check — no matching notification configuration found"
fi

# ------------------------------------------------------------------------------
# Check 6 — Lambda resource policy allows s3.amazonaws.com to invoke the function
# Check 7 — Resource policy is scoped to this specific bucket
#
# get-policy returns Policy as a JSON *string*, not a nested object — it must
# be parsed with jq's fromjson before inspecting Principal/Resource/Condition.
# ------------------------------------------------------------------------------
echo "Checking Lambda resource-based policy..."
POLICY_RAW=$(aws lambda get-policy \
  --function-name "$FUNCTION_NAME" \
  --query 'Policy' \
  --output text 2>/dev/null)

if [ -z "$POLICY_RAW" ] || [ "$POLICY_RAW" = "None" ]; then
  fail "Lambda resource policy" "No resource-based policy found on '${FUNCTION_NAME}' — S3 has not been granted invoke permission"
  fail "Resource policy bucket scope" "Cannot check — no resource policy found"
else
  POLICY_JSON=$(echo "$POLICY_RAW" | jq -c '.' 2>/dev/null)

  S3_STATEMENT=$(echo "$POLICY_JSON" | jq -c \
    '[.Statement[]? | select(.Principal.Service == "s3.amazonaws.com" and .Action == "lambda:InvokeFunction")] | .[0]' 2>/dev/null)

  if [ "$S3_STATEMENT" != "null" ] && [ -n "$S3_STATEMENT" ]; then
    pass "Lambda resource policy allows s3.amazonaws.com to invoke the function"

    SOURCE_ARN=$(echo "$S3_STATEMENT" | jq -r \
      '.Condition.ArnLike."AWS:SourceArn" // .Condition.ArnLike."aws:SourceArn" // empty' 2>/dev/null)
    EXPECTED_BUCKET_ARN="arn:aws:s3:::${BUCKET_NAME}"

    if [ "$SOURCE_ARN" = "$EXPECTED_BUCKET_ARN" ]; then
      pass "Resource policy is scoped to bucket '${BUCKET_NAME}'"
    elif [ -z "$SOURCE_ARN" ]; then
      fail "Resource policy bucket scope" "Statement allows s3.amazonaws.com but has no SourceArn condition — this permits ANY bucket in ANY account to invoke the function"
    else
      fail "Resource policy bucket scope" "SourceArn is '${SOURCE_ARN}' but expected '${EXPECTED_BUCKET_ARN}'"
    fi
  else
    fail "Lambda resource policy" "No statement found granting s3.amazonaws.com permission to call lambda:InvokeFunction"
    fail "Resource policy bucket scope" "Cannot check — no matching s3.amazonaws.com statement found"
  fi
fi

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
  echo " 🎉 Perfect score! All kata-204 requirements met."
  echo ""
fi

if [ "$FAIL" -gt 0 ]; then
  echo " Review the failed checks above, fix your infrastructure,"
  echo " and re-run this validator."
  echo ""
  exit 1
fi