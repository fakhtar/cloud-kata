#!/bin/bash

# ==============================================================================
# CloudKata Validator — kata-300
# Serverless API: Lambda, API Gateway & DynamoDB
# ==============================================================================

TABLE_NAME="kata-300-ItemsTable"
FUNCTION_NAME="kata-300-HandlerFunction"
API_NAME="kata-300-ItemsAPI"
RESOURCE_PATH="/items"
STAGE_NAME="prod"
TOTAL_CHECKS=15

PASS=0
FAIL=0

pass() { echo "✅ PASS — $1"; ((PASS++)); }
fail() { echo "❌ FAIL — $1"; ((FAIL++)); }

echo ""
echo "=================================================="
echo " CloudKata Validator — kata-300"
echo " Serverless API: Lambda, API Gateway & DynamoDB"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Resolve region
# ------------------------------------------------------------------------------
REGION=$(aws configure get region 2>/dev/null)
if [ -z "$REGION" ]; then
  REGION=$(aws ec2 describe-availability-zones \
    --query 'AvailabilityZones[0].RegionName' \
    --output text 2>/dev/null)
fi

# ------------------------------------------------------------------------------
# Check 1 — DynamoDB table exists (hard gate)
# ------------------------------------------------------------------------------
echo "Checking DynamoDB table..."
TABLE_JSON=$(aws dynamodb describe-table \
  --table-name "$TABLE_NAME" \
  --output json 2>/dev/null)

if [ -z "$TABLE_JSON" ] || [ "$TABLE_JSON" = "null" ]; then
  echo "❌ FAIL — DynamoDB table '$TABLE_NAME' not found. Cannot continue."
  echo ""
  echo "=================================================="
  echo " Results: 0/$TOTAL_CHECKS checks passed (0%)"
  echo "=================================================="
  exit 1
fi
pass "DynamoDB table '$TABLE_NAME' exists"

TABLE_ARN=$(echo "$TABLE_JSON" | jq -r '.Table.TableArn')

# ------------------------------------------------------------------------------
# Check 2 — Lambda function exists (hard gate)
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
  echo " Results: 1/$TOTAL_CHECKS checks passed (7%)"
  echo "=================================================="
  exit 1
fi
pass "Lambda function '$FUNCTION_NAME' exists"

FUNCTION_ARN=$(echo "$FUNCTION_JSON" | jq -r '.FunctionArn')

# ------------------------------------------------------------------------------
# Check 3 — TABLE_NAME environment variable is set correctly
# ------------------------------------------------------------------------------
echo "Checking TABLE_NAME environment variable..."
ENV_VARS=$(aws lambda get-function-configuration \
  --function-name "$FUNCTION_NAME" \
  --query 'Environment.Variables' \
  --output json 2>/dev/null)

ENV_TABLE=$(echo "$ENV_VARS" | jq -r '.TABLE_NAME // empty' 2>/dev/null)

if [ "$ENV_TABLE" = "$TABLE_NAME" ]; then
  pass "TABLE_NAME environment variable is set correctly"
else
  fail "TABLE_NAME environment variable is missing or incorrect — expected '$TABLE_NAME', got '${ENV_TABLE:-<not set>}'"
fi

# ------------------------------------------------------------------------------
# Check 4 — REST API exists (hard gate for API-dependent checks)
# ------------------------------------------------------------------------------
echo "Checking REST API..."
API_ID=$(aws apigateway get-rest-apis \
  --query "items[?name=='$API_NAME'].id" \
  --output text 2>/dev/null)

if [ -z "$API_ID" ] || [ "$API_ID" = "None" ]; then
  fail "REST API '$API_NAME' not found"
  fail "Resource '$RESOURCE_PATH' could not be checked — API not found"
  fail "POST method could not be checked — API not found"
  fail "GET method could not be checked — API not found"
  fail "Lambda proxy integration on POST could not be checked — API not found"
  fail "Lambda proxy integration on GET could not be checked — API not found"
  fail "Stage '$STAGE_NAME' could not be checked — API not found"
  fail "POST /items HTTP 201 could not be checked — API not found"
  fail "GET /items HTTP 200 could not be checked — API not found"
  fail "Required tags could not be checked on REST API — API not found"

  # Still run tag checks for DynamoDB table and Lambda function
  echo "Checking DynamoDB table tags..."
  DYNAMO_TAGS=$(aws dynamodb list-tags-of-resource \
    --resource-arn "$TABLE_ARN" \
    --output json 2>/dev/null)
  DYNAMO_PROJECT=$(echo "$DYNAMO_TAGS" | jq -r '.Tags[] | select(.Key=="Project") | .Value' 2>/dev/null)
  DYNAMO_KATA=$(echo "$DYNAMO_TAGS" | jq -r '.Tags[] | select(.Key=="Kata") | .Value' 2>/dev/null)
  if [ "$DYNAMO_PROJECT" = "CloudKata" ] && [ "$DYNAMO_KATA" = "kata-300" ]; then
    pass "Required tags are present on DynamoDB table"
  else
    fail "Missing or incorrect tags on DynamoDB table"
  fi

  echo "Checking Lambda function tags..."
  LAMBDA_TAGS=$(aws lambda list-tags \
    --resource "$FUNCTION_ARN" \
    --output json 2>/dev/null)
  LAMBDA_PROJECT=$(echo "$LAMBDA_TAGS" | jq -r '.Tags.Project // empty' 2>/dev/null)
  LAMBDA_KATA=$(echo "$LAMBDA_TAGS" | jq -r '.Tags.Kata // empty' 2>/dev/null)
  if [ "$LAMBDA_PROJECT" = "CloudKata" ] && [ "$LAMBDA_KATA" = "kata-300" ]; then
    pass "Required tags are present on Lambda function"
  else
    fail "Missing or incorrect tags on Lambda function"
  fi

  PCT=$(( (PASS * 100) / TOTAL_CHECKS ))
  echo ""
  echo "=================================================="
  echo " Results: $PASS/$TOTAL_CHECKS checks passed ($PCT%)"
  echo "=================================================="
  echo " 📖 Keep going — consult HINTS.md for guidance."
  echo ""
  exit 1
fi
pass "REST API '$API_NAME' exists"

# ------------------------------------------------------------------------------
# Check 5 — Resource /items exists
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
# Checks 6 & 7 — POST and GET methods exist on /items
# ------------------------------------------------------------------------------
echo "Checking POST method..."
POST_METHOD_JSON=""
GET_METHOD_JSON=""

if [ -z "$RESOURCE_ID" ]; then
  fail "POST method could not be checked — resource '$RESOURCE_PATH' not found"
  fail "GET method could not be checked — resource '$RESOURCE_PATH' not found"
else
  POST_METHOD_JSON=$(aws apigateway get-method \
    --rest-api-id "$API_ID" \
    --resource-id "$RESOURCE_ID" \
    --http-method POST \
    --output json 2>/dev/null)

  if [ -z "$POST_METHOD_JSON" ] || [ "$POST_METHOD_JSON" = "null" ]; then
    fail "POST method not found on '$RESOURCE_PATH'"
    POST_METHOD_JSON=""
  else
    pass "POST method exists on '$RESOURCE_PATH'"
  fi

  echo "Checking GET method..."
  GET_METHOD_JSON=$(aws apigateway get-method \
    --rest-api-id "$API_ID" \
    --resource-id "$RESOURCE_ID" \
    --http-method GET \
    --output json 2>/dev/null)

  if [ -z "$GET_METHOD_JSON" ] || [ "$GET_METHOD_JSON" = "null" ]; then
    fail "GET method not found on '$RESOURCE_PATH'"
    GET_METHOD_JSON=""
  else
    pass "GET method exists on '$RESOURCE_PATH'"
  fi
fi

# ------------------------------------------------------------------------------
# Check 8 — Lambda proxy integration on POST /items
# ------------------------------------------------------------------------------
echo "Checking Lambda proxy integration on POST..."
if [ -z "$POST_METHOD_JSON" ]; then
  fail "Lambda proxy integration on POST could not be checked — POST method not found"
else
  POST_INT_TYPE=$(echo "$POST_METHOD_JSON" | jq -r '.methodIntegration.type // empty')
  POST_INT_URI=$(echo "$POST_METHOD_JSON" | jq -r '.methodIntegration.uri // empty')
  if [ "$POST_INT_TYPE" = "AWS_PROXY" ] && echo "$POST_INT_URI" | grep -q "$FUNCTION_NAME"; then
    pass "Lambda proxy integration is configured on POST /items"
  else
    fail "Lambda proxy integration not configured correctly on POST /items — check integration type and target function"
  fi
fi

# ------------------------------------------------------------------------------
# Check 9 — Lambda proxy integration on GET /items
# ------------------------------------------------------------------------------
echo "Checking Lambda proxy integration on GET..."
if [ -z "$GET_METHOD_JSON" ]; then
  fail "Lambda proxy integration on GET could not be checked — GET method not found"
else
  GET_INT_TYPE=$(echo "$GET_METHOD_JSON" | jq -r '.methodIntegration.type // empty')
  GET_INT_URI=$(echo "$GET_METHOD_JSON" | jq -r '.methodIntegration.uri // empty')
  if [ "$GET_INT_TYPE" = "AWS_PROXY" ] && echo "$GET_INT_URI" | grep -q "$FUNCTION_NAME"; then
    pass "Lambda proxy integration is configured on GET /items"
  else
    fail "Lambda proxy integration not configured correctly on GET /items — check integration type and target function"
  fi
fi

# ------------------------------------------------------------------------------
# Check 10 — API deployed to stage 'prod'
# ------------------------------------------------------------------------------
echo "Checking stage '$STAGE_NAME'..."
STAGE_JSON=$(aws apigateway get-stage \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE_NAME" \
  --output json 2>/dev/null)

if [ -z "$STAGE_JSON" ] || [ "$STAGE_JSON" = "null" ]; then
  fail "Stage '$STAGE_NAME' not found — the API has not been deployed to '$STAGE_NAME'"
  STAGE_FOUND=false
else
  pass "API is deployed to stage '$STAGE_NAME'"
  STAGE_FOUND=true
fi

# ------------------------------------------------------------------------------
# Check 11 — POST /items returns HTTP 201
# ------------------------------------------------------------------------------
echo "Invoking POST /items..."
if [ "$STAGE_FOUND" = false ]; then
  fail "POST /items HTTP 201 could not be checked — stage '$STAGE_NAME' not found"
else
  ENDPOINT_BASE="https://${API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_NAME}"
  POST_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"name":"validator-test"}' \
    "${ENDPOINT_BASE}${RESOURCE_PATH}" 2>/dev/null)

  if [ "$POST_STATUS" = "201" ]; then
    pass "POST /items returns HTTP 201"
  else
    fail "POST /items returned HTTP $POST_STATUS — expected 201 (URL: ${ENDPOINT_BASE}${RESOURCE_PATH})"
  fi
fi

# ------------------------------------------------------------------------------
# Check 12 — GET /items returns HTTP 200
# ------------------------------------------------------------------------------
echo "Invoking GET /items..."
if [ "$STAGE_FOUND" = false ]; then
  fail "GET /items HTTP 200 could not be checked — stage '$STAGE_NAME' not found"
else
  GET_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    "${ENDPOINT_BASE}${RESOURCE_PATH}" 2>/dev/null)

  if [ "$GET_STATUS" = "200" ]; then
    pass "GET /items returns HTTP 200"
  else
    fail "GET /items returned HTTP $GET_STATUS — expected 200 (URL: ${ENDPOINT_BASE}${RESOURCE_PATH})"
  fi
fi

# ------------------------------------------------------------------------------
# Check 13 — Required tags on DynamoDB table
# ------------------------------------------------------------------------------
echo "Checking DynamoDB table tags..."
DYNAMO_TAGS=$(aws dynamodb list-tags-of-resource \
  --resource-arn "$TABLE_ARN" \
  --output json 2>/dev/null)

DYNAMO_PROJECT=$(echo "$DYNAMO_TAGS" | jq -r '.Tags[] | select(.Key=="Project") | .Value' 2>/dev/null)
DYNAMO_KATA=$(echo "$DYNAMO_TAGS" | jq -r '.Tags[] | select(.Key=="Kata") | .Value' 2>/dev/null)

if [ "$DYNAMO_PROJECT" = "CloudKata" ] && [ "$DYNAMO_KATA" = "kata-300" ]; then
  pass "Required tags are present on DynamoDB table"
else
  MISSING=""
  [ "$DYNAMO_PROJECT" != "CloudKata" ] && MISSING="Project: CloudKata "
  [ "$DYNAMO_KATA" != "kata-300" ] && MISSING="${MISSING}Kata: kata-300"
  fail "Missing or incorrect tags on DynamoDB table: $MISSING"
fi

# ------------------------------------------------------------------------------
# Check 14 — Required tags on Lambda function
# ------------------------------------------------------------------------------
echo "Checking Lambda function tags..."
LAMBDA_TAGS=$(aws lambda list-tags \
  --resource "$FUNCTION_ARN" \
  --output json 2>/dev/null)

LAMBDA_PROJECT=$(echo "$LAMBDA_TAGS" | jq -r '.Tags.Project // empty' 2>/dev/null)
LAMBDA_KATA=$(echo "$LAMBDA_TAGS" | jq -r '.Tags.Kata // empty' 2>/dev/null)

if [ "$LAMBDA_PROJECT" = "CloudKata" ] && [ "$LAMBDA_KATA" = "kata-300" ]; then
  pass "Required tags are present on Lambda function"
else
  MISSING=""
  [ "$LAMBDA_PROJECT" != "CloudKata" ] && MISSING="Project: CloudKata "
  [ "$LAMBDA_KATA" != "kata-300" ] && MISSING="${MISSING}Kata: kata-300"
  fail "Missing or incorrect tags on Lambda function: $MISSING"
fi

# ------------------------------------------------------------------------------
# Check 15 — Required tags on REST API
# ------------------------------------------------------------------------------
echo "Checking REST API tags..."
API_ARN="arn:aws:apigateway:${REGION}::/restapis/${API_ID}"
API_TAGS=$(aws apigateway get-tags \
  --resource-arn "$API_ARN" \
  --output json 2>/dev/null)

API_PROJECT=$(echo "$API_TAGS" | jq -r '.tags.Project // empty' 2>/dev/null)
API_KATA=$(echo "$API_TAGS" | jq -r '.tags.Kata // empty' 2>/dev/null)

if [ "$API_PROJECT" = "CloudKata" ] && [ "$API_KATA" = "kata-300" ]; then
  pass "Required tags are present on REST API"
else
  MISSING=""
  [ "$API_PROJECT" != "CloudKata" ] && MISSING="Project: CloudKata "
  [ "$API_KATA" != "kata-300" ] && MISSING="${MISSING}Kata: kata-300"
  fail "Missing or incorrect tags on REST API: $MISSING"
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
  echo " 🎉 Perfect score! All kata-300 requirements met."
elif [ "$PASS" -ge 10 ]; then
  echo " 🔧 Almost there — review the failed checks above."
else
  echo " 📖 Keep going — consult HINTS.md for guidance."
fi
echo ""