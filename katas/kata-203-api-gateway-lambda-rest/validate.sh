#!/bin/bash

# ==============================================================================
# CloudKata Validator — kata-203
# API Gateway + Lambda: REST API & Proxy Integration
# ==============================================================================

FUNCTION_NAME="kata-203-HandlerFunction"
API_NAME="kata-203-OrderAPI"
RESOURCE_PATH="/orders"
HTTP_METHOD="GET"
STAGE_NAME="prod"

PASS=0
FAIL=0

pass() { echo "✅ PASS — $1"; ((PASS++)); }
fail() { echo "❌ FAIL — $1"; ((FAIL++)); }

echo ""
echo "=================================================="
echo " CloudKata Validator — kata-203"
echo " API Gateway + Lambda: REST API & Proxy Integration"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Check 1 — Lambda function exists (hard gate)
# ------------------------------------------------------------------------------
echo "Checking Lambda function..."
FUNCTION_JSON=$(aws lambda get-function \
  --function-name "$FUNCTION_NAME" \
  --query 'Configuration' \
  --output json 2>/dev/null)

if [ -z "$FUNCTION_JSON" ] || [ "$FUNCTION_JSON" = "null" ]; then
  echo "❌ FAIL — Lambda function '$FUNCTION_NAME' not found. Cannot continue."
  echo ""
  echo "=================================================="
  echo " Results: 0/9 checks passed (0%)"
  echo "=================================================="
  exit 1
fi
pass "Lambda function '$FUNCTION_NAME' exists"

FUNCTION_ARN=$(echo "$FUNCTION_JSON" | jq -r '.FunctionArn')

# ------------------------------------------------------------------------------
# Check 2 — REST API exists (hard gate for remaining checks)
# ------------------------------------------------------------------------------
echo "Checking REST API..."
API_ID=$(aws apigateway get-rest-apis \
  --query "items[?name=='$API_NAME'].id" \
  --output text 2>/dev/null)

if [ -z "$API_ID" ] || [ "$API_ID" = "None" ]; then
  fail "REST API '$API_NAME' not found"
  # Fail all remaining API-dependent checks
  fail "Resource '$RESOURCE_PATH' could not be checked — API not found"
  fail "GET method could not be checked — API not found"
  fail "Lambda proxy integration could not be checked — API not found"
  fail "Stage '$STAGE_NAME' could not be checked — API not found"
  fail "Endpoint HTTP 200 could not be checked — API not found"
  fail "Required tags could not be checked on REST API — API not found"
  echo ""
  # Still run Lambda tag check (Check 8)
  echo "Checking Lambda function tags..."
  LAMBDA_TAGS=$(aws lambda list-tags \
    --resource "$FUNCTION_ARN" \
    --output json 2>/dev/null)
  LAMBDA_PROJECT=$(echo "$LAMBDA_TAGS" | jq -r '.Tags.Project // empty' 2>/dev/null)
  LAMBDA_KATA=$(echo "$LAMBDA_TAGS" | jq -r '.Tags.Kata // empty' 2>/dev/null)
  if [ "$LAMBDA_PROJECT" = "CloudKata" ] && [ "$LAMBDA_KATA" = "kata-203" ]; then
    pass "Required tags are present on Lambda function"
  else
    fail "Missing or incorrect tags on Lambda function"
  fi
  PCT=$(( (PASS * 100) / 9 ))
  echo ""
  echo "=================================================="
  echo " Results: $PASS/9 checks passed ($PCT%)"
  echo "=================================================="
  echo " 📖 Keep going — consult HINTS.md for guidance."
  echo ""
  exit 1
fi
pass "REST API '$API_NAME' exists"

# Build the region for constructing ARNs
REGION=$(aws configure get region 2>/dev/null)
if [ -z "$REGION" ]; then
  REGION=$(aws ec2 describe-availability-zones \
    --query 'AvailabilityZones[0].RegionName' \
    --output text 2>/dev/null)
fi

# ------------------------------------------------------------------------------
# Check 3 — Resource /orders exists
# ------------------------------------------------------------------------------
echo "Checking resource '$RESOURCE_PATH'..."
RESOURCE_JSON=$(aws apigateway get-resources \
  --rest-api-id "$API_ID" \
  --query "items[?path=='$RESOURCE_PATH']" \
  --output json 2>/dev/null)

RESOURCE_COUNT=$(echo "$RESOURCE_JSON" | jq 'length')
if [ "$RESOURCE_COUNT" -gt 0 ]; then
  pass "Resource '$RESOURCE_PATH' exists"
  RESOURCE_ID=$(echo "$RESOURCE_JSON" | jq -r '.[0].id')
else
  fail "Resource '$RESOURCE_PATH' not found on the REST API"
  RESOURCE_ID=""
fi

# ------------------------------------------------------------------------------
# Check 4 — GET method exists on /orders
# ------------------------------------------------------------------------------
echo "Checking GET method..."
if [ -z "$RESOURCE_ID" ]; then
  fail "GET method could not be checked — resource '$RESOURCE_PATH' not found"
  METHOD_JSON=""
else
  METHOD_JSON=$(aws apigateway get-method \
    --rest-api-id "$API_ID" \
    --resource-id "$RESOURCE_ID" \
    --http-method "$HTTP_METHOD" \
    --output json 2>/dev/null)

  if [ -z "$METHOD_JSON" ] || [ "$METHOD_JSON" = "null" ]; then
    fail "GET method not found on '$RESOURCE_PATH'"
    METHOD_JSON=""
  else
    pass "GET method exists on '$RESOURCE_PATH'"
  fi
fi

# ------------------------------------------------------------------------------
# Check 5 — Lambda proxy integration is configured
# ------------------------------------------------------------------------------
echo "Checking Lambda proxy integration..."
if [ -z "$METHOD_JSON" ]; then
  fail "Lambda proxy integration could not be checked — GET method not found"
else
  INTEGRATION_TYPE=$(echo "$METHOD_JSON" | jq -r '.methodIntegration.type // empty')
  INTEGRATION_URI=$(echo "$METHOD_JSON" | jq -r '.methodIntegration.uri // empty')

  # type must be AWS_PROXY and URI must reference the function name
  if [ "$INTEGRATION_TYPE" = "AWS_PROXY" ] && \
     echo "$INTEGRATION_URI" | grep -q "$FUNCTION_NAME"; then
    pass "Lambda proxy integration is configured"
  else
    fail "Lambda proxy integration is not configured correctly — check integration type and target function"
  fi
fi

# ------------------------------------------------------------------------------
# Check 6 — API is deployed to stage 'prod'
# ------------------------------------------------------------------------------
echo "Checking stage '$STAGE_NAME'..."
STAGE_JSON=$(aws apigateway get-stage \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE_NAME" \
  --output json 2>/dev/null)

if [ -z "$STAGE_JSON" ] || [ "$STAGE_JSON" = "null" ]; then
  fail "Stage '$STAGE_NAME' not found — the API has not been deployed to '$STAGE_NAME'"
else
  pass "API is deployed to stage '$STAGE_NAME'"
fi

# ------------------------------------------------------------------------------
# Check 7 — Endpoint returns HTTP 200
# ------------------------------------------------------------------------------
echo "Invoking endpoint..."
if [ -z "$STAGE_JSON" ]; then
  fail "Endpoint HTTP 200 could not be checked — stage '$STAGE_NAME' not found"
else
  ENDPOINT_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_NAME}${RESOURCE_PATH}"
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$ENDPOINT_URL" 2>/dev/null)

  if [ "$HTTP_STATUS" = "200" ]; then
    pass "Endpoint returns HTTP 200"
  else
    fail "Endpoint returned HTTP $HTTP_STATUS — expected 200 (URL: $ENDPOINT_URL)"
  fi
fi

# ------------------------------------------------------------------------------
# Check 8 — Required tags on Lambda function
# ------------------------------------------------------------------------------
echo "Checking Lambda function tags..."
LAMBDA_TAGS=$(aws lambda list-tags \
  --resource "$FUNCTION_ARN" \
  --output json 2>/dev/null)

LAMBDA_PROJECT=$(echo "$LAMBDA_TAGS" | jq -r '.Tags.Project // empty' 2>/dev/null)
LAMBDA_KATA=$(echo "$LAMBDA_TAGS" | jq -r '.Tags.Kata // empty' 2>/dev/null)

if [ "$LAMBDA_PROJECT" = "CloudKata" ] && [ "$LAMBDA_KATA" = "kata-203" ]; then
  pass "Required tags are present on Lambda function"
else
  MISSING=""
  [ "$LAMBDA_PROJECT" != "CloudKata" ] && MISSING="Project: CloudKata "
  [ "$LAMBDA_KATA" != "kata-203" ] && MISSING="${MISSING}Kata: kata-203"
  fail "Missing or incorrect tags on Lambda function: $MISSING"
fi

# ------------------------------------------------------------------------------
# Check 9 — Required tags on REST API
# ------------------------------------------------------------------------------
echo "Checking REST API tags..."
API_ARN="arn:aws:apigateway:${REGION}::/restapis/${API_ID}"
API_TAGS=$(aws apigateway get-tags \
  --resource-arn "$API_ARN" \
  --output json 2>/dev/null)

API_PROJECT=$(echo "$API_TAGS" | jq -r '.tags.Project // empty' 2>/dev/null)
API_KATA=$(echo "$API_TAGS" | jq -r '.tags.Kata // empty' 2>/dev/null)

if [ "$API_PROJECT" = "CloudKata" ] && [ "$API_KATA" = "kata-203" ]; then
  pass "Required tags are present on REST API"
else
  MISSING=""
  [ "$API_PROJECT" != "CloudKata" ] && MISSING="Project: CloudKata "
  [ "$API_KATA" != "kata-203" ] && MISSING="${MISSING}Kata: kata-203"
  fail "Missing or incorrect tags on REST API: $MISSING"
fi

# ------------------------------------------------------------------------------
# Results
# ------------------------------------------------------------------------------
PCT=$(( (PASS * 100) / 9 ))

echo ""
echo "=================================================="
echo " Results: $PASS/9 checks passed ($PCT%)"
echo "=================================================="

if [ "$PASS" -eq 9 ]; then
  echo " 🎉 Perfect score! All kata-203 requirements met."
elif [ "$PASS" -ge 6 ]; then
  echo " 🔧 Almost there — review the failed checks above."
else
  echo " 📖 Keep going — consult HINTS.md for guidance."
fi
echo ""