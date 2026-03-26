#!/bin/bash

# ==============================================================================
# CloudKata Validator — kata-201
# DynamoDB Core: Tables, Keys, Indexes & Capacity Modes
# ==============================================================================

TABLE_NAME="kata-201-Orders"
GSI_NAME="kata-201-CustomerEmail-index"
PARTITION_KEY="OrderId"
SORT_KEY="CreatedAt"
GSI_PARTITION_KEY="CustomerEmail"

PASS=0
FAIL=0

pass() { echo "✅ PASS — $1"; ((PASS++)); }
fail() { echo "❌ FAIL — $1"; ((FAIL++)); }

echo ""
echo "=================================================="
echo " CloudKata Validator — kata-201"
echo " DynamoDB Core: Tables, Keys, Indexes & Capacity Modes"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Check 1 — Table exists (hard gate)
# ------------------------------------------------------------------------------
echo "Checking table existence..."
TABLE_JSON=$(aws dynamodb describe-table \
  --table-name "$TABLE_NAME" \
  --query 'Table' \
  --output json 2>/dev/null)

if [ -z "$TABLE_JSON" ] || [ "$TABLE_JSON" = "null" ]; then
  echo "❌ FAIL — Table '$TABLE_NAME' not found. Cannot continue."
  echo ""
  echo "=================================================="
  echo " Results: 0/9 checks passed (0%)"
  echo "=================================================="
  exit 1
fi
pass "Table '$TABLE_NAME' exists"

# ------------------------------------------------------------------------------
# Check 2 — Table status is ACTIVE
# ------------------------------------------------------------------------------
echo "Checking table status..."
TABLE_STATUS=$(echo "$TABLE_JSON" | jq -r '.TableStatus')

if [ "$TABLE_STATUS" = "ACTIVE" ]; then
  pass "Table status is ACTIVE"
else
  fail "Table status is '$TABLE_STATUS' — must be ACTIVE"
fi

# ------------------------------------------------------------------------------
# Check 3 — Partition key is OrderId (String)
# ------------------------------------------------------------------------------
echo "Checking partition key..."
HASH_KEY=$(echo "$TABLE_JSON" | \
  jq -r '.KeySchema[] | select(.KeyType == "HASH") | .AttributeName')
HASH_TYPE=$(echo "$TABLE_JSON" | \
  jq -r --arg key "$HASH_KEY" \
  '.AttributeDefinitions[] | select(.AttributeName == $key) | .AttributeType')

if [ "$HASH_KEY" = "$PARTITION_KEY" ] && [ "$HASH_TYPE" = "S" ]; then
  pass "Partition key is correct"
else
  fail "Partition key is incorrect — check the attribute name and type required by the access pattern"
fi

# ------------------------------------------------------------------------------
# Check 4 — Sort key is CreatedAt (String)
# ------------------------------------------------------------------------------
echo "Checking sort key..."
RANGE_KEY=$(echo "$TABLE_JSON" | \
  jq -r '.KeySchema[] | select(.KeyType == "RANGE") | .AttributeName')
RANGE_TYPE=$(echo "$TABLE_JSON" | \
  jq -r --arg key "$RANGE_KEY" \
  '.AttributeDefinitions[] | select(.AttributeName == $key) | .AttributeType')

if [ "$RANGE_KEY" = "$SORT_KEY" ] && [ "$RANGE_TYPE" = "S" ]; then
  pass "Sort key is correct"
else
  fail "Sort key is incorrect — check the attribute name and type required by the access pattern"
fi

# ------------------------------------------------------------------------------
# Check 5 — Capacity mode is PAY_PER_REQUEST (on-demand)
# ------------------------------------------------------------------------------
echo "Checking capacity mode..."
BILLING_MODE=$(echo "$TABLE_JSON" | jq -r '.BillingModeSummary.BillingMode // "PROVISIONED"')

if [ "$BILLING_MODE" = "PAY_PER_REQUEST" ]; then
  pass "Capacity mode is configured correctly"
else
  fail "Capacity mode is '$BILLING_MODE' — the workload described requires a different capacity mode"
fi

# ------------------------------------------------------------------------------
# Check 6 — GSI exists
# ------------------------------------------------------------------------------
echo "Checking Global Secondary Index..."
GSI_JSON=$(echo "$TABLE_JSON" | \
  jq -r --arg idx "$GSI_NAME" \
  '.GlobalSecondaryIndexes[] | select(.IndexName == $idx)' 2>/dev/null)

if [ -z "$GSI_JSON" ] || [ "$GSI_JSON" = "null" ]; then
  fail "GSI '$GSI_NAME' not found"
  # Fail remaining GSI checks
  fail "GSI partition key could not be checked — GSI not found"
  fail "GSI projection could not be checked — GSI not found"
else
  pass "GSI '$GSI_NAME' exists"

  # ----------------------------------------------------------------------------
  # Check 7 — GSI partition key is CustomerEmail (String)
  # ----------------------------------------------------------------------------
  echo "Checking GSI partition key..."
  GSI_HASH_KEY=$(echo "$GSI_JSON" | \
    jq -r '.KeySchema[] | select(.KeyType == "HASH") | .AttributeName')
  GSI_HASH_TYPE=$(echo "$TABLE_JSON" | \
    jq -r --arg key "$GSI_HASH_KEY" \
    '.AttributeDefinitions[] | select(.AttributeName == $key) | .AttributeType')

  if [ "$GSI_HASH_KEY" = "$GSI_PARTITION_KEY" ] && [ "$GSI_HASH_TYPE" = "S" ]; then
    pass "GSI partition key is correct"
  else
    fail "GSI partition key is incorrect — check which attribute enables the customer access pattern"
  fi

  # ----------------------------------------------------------------------------
  # Check 8 — GSI projection type is ALL
  # ----------------------------------------------------------------------------
  echo "Checking GSI projection..."
  GSI_PROJECTION=$(echo "$GSI_JSON" | jq -r '.Projection.ProjectionType')

  if [ "$GSI_PROJECTION" = "ALL" ]; then
    pass "GSI projection is correct"
  else
    fail "GSI projection is incorrect — all primary table attributes must be readable via the index"
  fi
fi

# ------------------------------------------------------------------------------
# Check 9 — Required tags are present
# ------------------------------------------------------------------------------
echo "Checking tags..."
TABLE_ARN=$(echo "$TABLE_JSON" | jq -r '.TableArn')
TAGS_JSON=$(aws dynamodb list-tags-of-resource \
  --resource-arn "$TABLE_ARN" \
  --query 'Tags' \
  --output json 2>/dev/null)

PROJECT_TAG=$(echo "$TAGS_JSON" | \
  jq -r '.[] | select(.Key == "Project") | .Value' 2>/dev/null)
KATA_TAG=$(echo "$TAGS_JSON" | \
  jq -r '.[] | select(.Key == "Kata") | .Value' 2>/dev/null)

if [ "$PROJECT_TAG" = "CloudKata" ] && [ "$KATA_TAG" = "kata-201" ]; then
  pass "Required tags are present (Project: CloudKata, Kata: kata-201)"
else
  MISSING=""
  [ "$PROJECT_TAG" != "CloudKata" ] && MISSING="Project: CloudKata "
  [ "$KATA_TAG" != "kata-201" ] && MISSING="${MISSING}Kata: kata-201"
  fail "Missing or incorrect tags: $MISSING"
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
  echo " 🎉 Perfect score! All kata-201 requirements met."
elif [ "$PASS" -ge 6 ]; then
  echo " 🔧 Almost there — review the failed checks above."
else
  echo " 📖 Keep going — consult HINTS.md for guidance."
fi
echo ""