#!/bin/bash

# ==============================================================================
# CloudKata Validator — kata-101
# IAM Fundamentals: Roles, Policies & Trust Relationships
# ==============================================================================

ROLE_NAME="kata-101-LambdaExecutionRole"
POLICY_NAME="kata-101-LambdaExecutionPolicy"
TABLE_NAME="kata-101-OrdersTable"
LOG_GROUP_PREFIX="/aws/lambda/kata-101-"

PASS=0
FAIL=0

pass() { echo "✅ PASS — $1"; ((PASS++)); }
fail() { echo "❌ FAIL — $1"; ((FAIL++)); }

# Broad AWS managed policies that indicate least privilege violation
BROAD_POLICIES=(
  "AdministratorAccess"
  "PowerUserAccess"
  "AmazonDynamoDBFullAccess"
  "AmazonDynamoDBReadOnlyAccess"
  "AWSLambdaFullAccess"
  "AWSLambdaBasicExecutionRole"
  "CloudWatchFullAccess"
  "CloudWatchLogsFullAccess"
)

# Required DynamoDB actions (exact set — no more, no less)
REQUIRED_DYNAMO_ACTIONS=(
  "dynamodb:getitem"
  "dynamodb:putitem"
  "dynamodb:updateitem"
  "dynamodb:deleteitem"
)

# Required CloudWatch Logs actions (exact set — no more, no less)
REQUIRED_LOGS_ACTIONS=(
  "logs:createloggroup"
  "logs:createlogstream"
  "logs:putlogevents"
)

echo ""
echo "=================================================="
echo " CloudKata Validator — kata-101"
echo " IAM Fundamentals: Roles, Policies & Trust Relationships"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Check 1 — Role exists (hard gate)
# ------------------------------------------------------------------------------
echo "Checking role existence..."
ROLE_JSON=$(aws iam get-role --role-name "$ROLE_NAME" 2>/dev/null)
if [ -z "$ROLE_JSON" ]; then
  echo "❌ FAIL — Role '$ROLE_NAME' not found. Cannot continue."
  echo ""
  echo "=================================================="
  echo " Results: 0/11 checks passed (0%)"
  echo "=================================================="
  exit 1
fi
pass "Role '$ROLE_NAME' exists"

# ------------------------------------------------------------------------------
# Check 2 — Trust policy allows lambda.amazonaws.com only
# ------------------------------------------------------------------------------
echo "Checking trust policy principal..."
TRUST_DOC=$(echo "$ROLE_JSON" | jq -r '.Role.AssumeRolePolicyDocument')
TRUST_PRINCIPALS=$(echo "$TRUST_DOC" | jq -r '[.Statement[].Principal | if type == "object" then (.Service // empty) else . end] | flatten | .[]' 2>/dev/null)

HAS_LAMBDA=false
HAS_OTHER=false

while IFS= read -r principal; do
  if [ "$principal" = "lambda.amazonaws.com" ]; then
    HAS_LAMBDA=true
  elif [ -n "$principal" ]; then
    HAS_OTHER=true
  fi
done <<< "$TRUST_PRINCIPALS"

if [ "$HAS_LAMBDA" = true ]; then
  pass "Trust policy allows lambda.amazonaws.com"
else
  fail "Trust policy does not allow lambda.amazonaws.com"
fi

# ------------------------------------------------------------------------------
# Check 3 — No overly broad principals in trust policy
# ------------------------------------------------------------------------------
echo "Checking trust policy for overly broad principals..."
WILDCARD_PRINCIPAL=$(echo "$TRUST_DOC" | jq -r '[.Statement[].Principal] | flatten | .[]' 2>/dev/null | grep -c '^\*$' || true)

if [ "$HAS_OTHER" = true ] || [ "$WILDCARD_PRINCIPAL" -gt 0 ]; then
  fail "Trust policy contains principals other than lambda.amazonaws.com"
else
  pass "Trust policy is scoped to lambda.amazonaws.com only"
fi

# ------------------------------------------------------------------------------
# Check 4 — Customer managed policy exists (hard gate)
# ------------------------------------------------------------------------------
echo "Checking policy existence..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

POLICY_JSON=$(aws iam get-policy --policy-arn "$POLICY_ARN" 2>/dev/null)
if [ -z "$POLICY_JSON" ]; then
  fail "Policy '$POLICY_NAME' not found — remaining checks skipped"
  echo ""
  echo "=================================================="
  TOTAL=$((PASS + FAIL))
  PCT=$(( (PASS * 100) / 11 ))
  echo " Results: $PASS/11 checks passed ($PCT%)"
  echo "=================================================="
  exit 1
fi
pass "Policy '$POLICY_NAME' exists"

# ------------------------------------------------------------------------------
# Retrieve active policy version document
# ------------------------------------------------------------------------------
VERSION_ID=$(echo "$POLICY_JSON" | jq -r '.Policy.DefaultVersionId')
POLICY_DOC=$(aws iam get-policy-version \
  --policy-arn "$POLICY_ARN" \
  --version-id "$VERSION_ID" \
  --query 'PolicyVersion.Document' \
  --output json 2>/dev/null)

if [ -z "$POLICY_DOC" ]; then
  fail "Could not retrieve policy document — remaining checks skipped"
  echo ""
  echo "=================================================="
  TOTAL=$((PASS + FAIL))
  PCT=$(( (PASS * 100) / 11 ))
  echo " Results: $PASS/11 checks passed ($PCT%)"
  echo "=================================================="
  exit 1
fi

# Flatten all actions and resources across all statements
ALL_ACTIONS=$(echo "$POLICY_DOC" | jq -r '[.Statement[].Action] | flatten | map(ascii_downcase) | unique | .[]')
ALL_DYNAMO_RESOURCES=$(echo "$POLICY_DOC" | jq -r '[.Statement[] | select(.Action | if type=="array" then any(test("(?i)dynamodb:")) else test("(?i)dynamodb:") end) | .Resource] | flatten | unique | .[]' 2>/dev/null)
ALL_LOGS_RESOURCES=$(echo "$POLICY_DOC" | jq -r '[.Statement[] | select(.Action | if type=="array" then any(test("(?i)logs:")) else test("(?i)logs:") end) | .Resource] | flatten | unique | .[]' 2>/dev/null)

# ------------------------------------------------------------------------------
# Check 5 — All required DynamoDB actions are present (exact match)
# ------------------------------------------------------------------------------
echo "Checking required DynamoDB actions..."
DYNAMO_ACTIONS_IN_POLICY=$(echo "$ALL_ACTIONS" | grep "^dynamodb:" || true)
DYNAMO_PASS=true

for action in "${REQUIRED_DYNAMO_ACTIONS[@]}"; do
  if ! echo "$DYNAMO_ACTIONS_IN_POLICY" | grep -qi "^${action}$"; then
    DYNAMO_PASS=false
    break
  fi
done

# Also check for extra DynamoDB actions beyond the required set
EXTRA_DYNAMO=false
while IFS= read -r action; do
  [ -z "$action" ] && continue
  FOUND=false
  for required in "${REQUIRED_DYNAMO_ACTIONS[@]}"; do
    if [ "$action" = "$required" ]; then
      FOUND=true
      break
    fi
  done
  if [ "$FOUND" = false ]; then
    EXTRA_DYNAMO=true
    break
  fi
done <<< "$DYNAMO_ACTIONS_IN_POLICY"

if [ "$DYNAMO_PASS" = true ] && [ "$EXTRA_DYNAMO" = false ]; then
  pass "DynamoDB actions are exactly correct (no more, no less)"
elif [ "$DYNAMO_PASS" = false ]; then
  fail "One or more required DynamoDB actions are missing"
else
  fail "Policy contains extra DynamoDB actions beyond the required set"
fi

# ------------------------------------------------------------------------------
# Check 6 — All required CloudWatch Logs actions are present (exact match)
# ------------------------------------------------------------------------------
echo "Checking required CloudWatch Logs actions..."
LOGS_ACTIONS_IN_POLICY=$(echo "$ALL_ACTIONS" | grep "^logs:" || true)
LOGS_PASS=true

for action in "${REQUIRED_LOGS_ACTIONS[@]}"; do
  if ! echo "$LOGS_ACTIONS_IN_POLICY" | grep -qi "^${action}$"; then
    LOGS_PASS=false
    break
  fi
done

EXTRA_LOGS=false
while IFS= read -r action; do
  [ -z "$action" ] && continue
  FOUND=false
  for required in "${REQUIRED_LOGS_ACTIONS[@]}"; do
    if [ "$action" = "$required" ]; then
      FOUND=true
      break
    fi
  done
  if [ "$FOUND" = false ]; then
    EXTRA_LOGS=true
    break
  fi
done <<< "$LOGS_ACTIONS_IN_POLICY"

if [ "$LOGS_PASS" = true ] && [ "$EXTRA_LOGS" = false ]; then
  pass "CloudWatch Logs actions are exactly correct (no more, no less)"
elif [ "$LOGS_PASS" = false ]; then
  fail "One or more required CloudWatch Logs actions are missing"
else
  fail "Policy contains extra CloudWatch Logs actions beyond the required set"
fi

# ------------------------------------------------------------------------------
# Check 7 — No wildcard actions anywhere in the policy
# ------------------------------------------------------------------------------
echo "Checking for wildcard actions..."
HAS_WILDCARD=$(echo "$ALL_ACTIONS" | grep -E '^\*$|:\*$' || true)
if [ -z "$HAS_WILDCARD" ]; then
  pass "No wildcard actions found in policy"
else
  fail "Policy contains wildcard actions: $HAS_WILDCARD"
fi

# ------------------------------------------------------------------------------
# Check 8 — DynamoDB actions scoped to specific table ARN (not *)
# ------------------------------------------------------------------------------
echo "Checking DynamoDB resource scoping..."
DYNAMO_WILDCARD=false
DYNAMO_SCOPED=false

while IFS= read -r resource; do
  [ -z "$resource" ] && continue
  if [ "$resource" = "*" ]; then
    DYNAMO_WILDCARD=true
  elif echo "$resource" | grep -q "table/${TABLE_NAME}$"; then
    DYNAMO_SCOPED=true
  fi
done <<< "$ALL_DYNAMO_RESOURCES"

if [ "$DYNAMO_WILDCARD" = true ]; then
  fail "DynamoDB resource is set to '*' — must be scoped to a specific table ARN"
elif [ "$DYNAMO_SCOPED" = true ]; then
  pass "DynamoDB actions are scoped to table '$TABLE_NAME'"
else
  fail "DynamoDB resource does not reference table '$TABLE_NAME'"
fi

# ------------------------------------------------------------------------------
# Check 9 — CloudWatch Logs resource is scoped (not *)
# ------------------------------------------------------------------------------
echo "Checking CloudWatch Logs resource scoping..."
LOGS_WILDCARD=false
LOGS_SCOPED=false

while IFS= read -r resource; do
  [ -z "$resource" ] && continue
  if [ "$resource" = "*" ]; then
    LOGS_WILDCARD=true
  elif echo "$resource" | grep -q "$LOG_GROUP_PREFIX"; then
    LOGS_SCOPED=true
  fi
done <<< "$ALL_LOGS_RESOURCES"

if [ "$LOGS_WILDCARD" = true ]; then
  fail "CloudWatch Logs resource is set to '*' — must be scoped to a specific log group"
elif [ "$LOGS_SCOPED" = true ]; then
  pass "CloudWatch Logs actions are scoped to log group prefix '$LOG_GROUP_PREFIX'"
else
  fail "CloudWatch Logs resource does not reference log group prefix '$LOG_GROUP_PREFIX'"
fi

# ------------------------------------------------------------------------------
# Check 10 — No overly broad AWS managed policies attached
# ------------------------------------------------------------------------------
echo "Checking for overly broad managed policies..."
ATTACHED_POLICIES=$(aws iam list-attached-role-policies \
  --role-name "$ROLE_NAME" \
  --query 'AttachedPolicies[].PolicyName' \
  --output json 2>/dev/null)

BROAD_FOUND=false
for broad in "${BROAD_POLICIES[@]}"; do
  if echo "$ATTACHED_POLICIES" | jq -e --arg p "$broad" '.[] | select(. == $p)' > /dev/null 2>&1; then
    BROAD_FOUND=true
    fail "Overly broad managed policy attached: '$broad'"
    break
  fi
done

if [ "$BROAD_FOUND" = false ]; then
  pass "No overly broad managed policies attached"
fi

# ------------------------------------------------------------------------------
# Check 11 — Policy is attached to the role
# ------------------------------------------------------------------------------
echo "Checking policy attachment..."
IS_ATTACHED=$(echo "$ATTACHED_POLICIES" | jq -e --arg p "$POLICY_NAME" '.[] | select(. == $p)' 2>/dev/null)

if [ -n "$IS_ATTACHED" ]; then
  pass "Policy '$POLICY_NAME' is attached to role '$ROLE_NAME'"
else
  fail "Policy '$POLICY_NAME' is not attached to role '$ROLE_NAME'"
fi

# ------------------------------------------------------------------------------
# Results
# ------------------------------------------------------------------------------
TOTAL=$((PASS + FAIL))
PCT=$(( (PASS * 100) / 11 ))

echo ""
echo "=================================================="
echo " Results: $PASS/11 checks passed ($PCT%)"
echo "=================================================="

if [ "$PASS" -eq 11 ]; then
  echo " 🎉 Perfect score! All kata-101 requirements met."
elif [ "$PASS" -ge 8 ]; then
  echo " 🔧 Almost there — review the failed checks above."
else
  echo " 📖 Keep going — consult HINTS.md for guidance."
fi
echo ""