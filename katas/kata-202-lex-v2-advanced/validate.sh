#!/bin/bash

# ==============================================================================
# CloudKata Validator — kata-202
# Amazon Lex V2 Advanced: Versioning, Aliases & Lambda Fulfillment
# ==============================================================================

BOT_NAME="kata-202-FoodOrderingBot"
ALIAS_NAME="kata-202-ProductionAlias"
FUNCTION_NAME="kata-202-FulfillmentFunction"

PASS=0
FAIL=0

pass() { echo "✅ PASS — $1"; ((PASS++)); }
fail() { echo "❌ FAIL — $1"; ((FAIL++)); }

echo ""
echo "=================================================="
echo " CloudKata Validator — kata-202"
echo " Amazon Lex V2 Advanced: Versioning, Aliases & Lambda Fulfillment"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Check 1 — Lambda function exists (hard gate)
# ------------------------------------------------------------------------------
echo "Checking Lambda function..."
FUNCTION_JSON=$(aws lambda get-function-configuration \
  --function-name "$FUNCTION_NAME" 2>/dev/null)

if [ -z "$FUNCTION_JSON" ]; then
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
# Check 2 — Bot exists (hard gate)
# ------------------------------------------------------------------------------
echo "Checking bot existence..."
BOT_JSON=$(aws lexv2-models list-bots \
  --query "botSummaries[?botName=='${BOT_NAME}'] | [0]" \
  --output json 2>/dev/null)

BOT_ID=$(echo "$BOT_JSON" | jq -r '.botId // empty')

if [ -z "$BOT_ID" ] || [ "$BOT_ID" = "null" ]; then
  echo "❌ FAIL — Bot '$BOT_NAME' not found. Cannot continue."
  echo ""
  echo "=================================================="
  echo " Results: 1/9 checks passed (11%)"
  echo "=================================================="
  exit 1
fi
pass "Bot '$BOT_NAME' exists (ID: $BOT_ID)"

# ------------------------------------------------------------------------------
# Check 3 — Bot status is Available
# ------------------------------------------------------------------------------
echo "Checking bot status..."
BOT_STATUS=$(echo "$BOT_JSON" | jq -r '.botStatus')

if [ "$BOT_STATUS" = "Available" ]; then
  pass "Bot status is Available"
else
  fail "Bot status is '$BOT_STATUS' — must be Available"
fi

# ------------------------------------------------------------------------------
# Check 4 — OrderFood intent has fulfillment invocation enabled
# ------------------------------------------------------------------------------
echo "Checking OrderFood fulfillment configuration..."
INTENT_LIST=$(aws lexv2-models list-intents \
  --bot-id "$BOT_ID" \
  --bot-version "DRAFT" \
  --locale-id "en_US" \
  --query "intentSummaries[?intentName=='OrderFood'] | [0]" \
  --output json 2>/dev/null)

INTENT_ID=$(echo "$INTENT_LIST" | jq -r '.intentId // empty')

if [ -z "$INTENT_ID" ] || [ "$INTENT_ID" = "null" ]; then
  fail "Intent 'OrderFood' not found — cannot check fulfillment configuration"
else
  INTENT_DETAIL=$(aws lexv2-models describe-intent \
    --bot-id "$BOT_ID" \
    --bot-version "DRAFT" \
    --locale-id "en_US" \
    --intent-id "$INTENT_ID" \
    --output json 2>/dev/null)

  FULFILLMENT_ENABLED=$(echo "$INTENT_DETAIL" | \
    jq -r '.fulfillmentCodeHook.enabled // false')
  FULFILLMENT_ACTIVE=$(echo "$INTENT_DETAIL" | \
    jq -r '.fulfillmentCodeHook.active // false')

  if [ "$FULFILLMENT_ENABLED" = "true" ] && [ "$FULFILLMENT_ACTIVE" = "true" ]; then
    pass "OrderFood intent has fulfillment invocation enabled"
  elif [ "$FULFILLMENT_ENABLED" = "true" ]; then
    fail "OrderFood fulfillment is enabled but not active — check the fulfillment code hook active setting"
  else
    fail "OrderFood intent does not have fulfillment invocation enabled"
  fi
fi

# ------------------------------------------------------------------------------
# Check 5 — A published numeric bot version exists
# ------------------------------------------------------------------------------
echo "Checking bot versions..."
VERSIONS=$(aws lexv2-models list-bot-versions \
  --bot-id "$BOT_ID" \
  --query "botVersionSummaries[?botVersion!='DRAFT'].botVersion" \
  --output json 2>/dev/null)

VERSION_COUNT=$(echo "$VERSIONS" | jq 'length')
PUBLISHED_VERSION=$(echo "$VERSIONS" | jq -r '.[0] // empty')

if [ "$VERSION_COUNT" -gt 0 ] && [ -n "$PUBLISHED_VERSION" ]; then
  pass "A published numeric bot version exists (version: $PUBLISHED_VERSION)"
else
  fail "No published numeric bot version found — only DRAFT exists"
fi

# ------------------------------------------------------------------------------
# Check 6 — Production alias exists
# ------------------------------------------------------------------------------
echo "Checking production alias..."
ALIAS_LIST=$(aws lexv2-models list-bot-aliases \
  --bot-id "$BOT_ID" \
  --query "botAliasSummaries[?botAliasName=='${ALIAS_NAME}'] | [0]" \
  --output json 2>/dev/null)

ALIAS_ID=$(echo "$ALIAS_LIST" | jq -r '.botAliasId // empty')

if [ -z "$ALIAS_ID" ] || [ "$ALIAS_ID" = "null" ]; then
  fail "Alias '$ALIAS_NAME' not found"
  fail "Alias version check skipped — alias not found"
  fail "Lambda code hook check skipped — alias not found"
else
  pass "Alias '$ALIAS_NAME' exists"

  ALIAS_DETAIL=$(aws lexv2-models describe-bot-alias \
    --bot-id "$BOT_ID" \
    --bot-alias-id "$ALIAS_ID" \
    --output json 2>/dev/null)

  # ----------------------------------------------------------------------------
  # Check 7 — Alias points to a published numeric version (not DRAFT)
  # ----------------------------------------------------------------------------
  echo "Checking alias bot version..."
  ALIAS_BOT_VERSION=$(echo "$ALIAS_DETAIL" | jq -r '.botVersion // empty')

  if [ -z "$ALIAS_BOT_VERSION" ] || [ "$ALIAS_BOT_VERSION" = "null" ]; then
    fail "Alias does not have a bot version configured"
  elif [ "$ALIAS_BOT_VERSION" = "DRAFT" ]; then
    fail "Alias points to DRAFT — must point to a published numeric version"
  else
    # Verify it's a numeric version
    if [[ "$ALIAS_BOT_VERSION" =~ ^[0-9]+$ ]]; then
      pass "Alias points to published numeric version $ALIAS_BOT_VERSION"
    else
      fail "Alias bot version '$ALIAS_BOT_VERSION' is not a numeric version"
    fi
  fi

  # ----------------------------------------------------------------------------
  # Check 8 — Lambda is configured as code hook on the alias for en_US
  # The CLI returns botAliasLocaleSettings as a map keyed by locale ID.
  # Try both camelCase variations as the CLI output format has varied.
  # ----------------------------------------------------------------------------
  echo "Checking Lambda code hook on alias..."
  LAMBDA_ARN_ON_ALIAS=$(echo "$ALIAS_DETAIL" | \
    jq -r '
      (.botAliasLocaleSettings["en_US"].codeHookSpecification.lambdaCodeHook.lambdaArn
      // .botAliasLocaleSettings["en_US"].codeHookSpecification.lambdaCodeHook.lambdaARN
      // empty)
    ' 2>/dev/null)

  if [ -z "$LAMBDA_ARN_ON_ALIAS" ]; then
    fail "Lambda is not configured as code hook on alias for en_US"
  elif echo "$LAMBDA_ARN_ON_ALIAS" | grep -q "$FUNCTION_NAME"; then
    pass "Lambda is configured as code hook on the alias"
  else
    fail "Lambda configured on alias does not match '$FUNCTION_NAME'"
  fi
fi

# ------------------------------------------------------------------------------
# Check 9 — Bot responds correctly via production alias
# ------------------------------------------------------------------------------
echo "Invoking bot via production alias..."

if [ -z "$ALIAS_ID" ]; then
  fail "Runtime invocation skipped — alias not found"
else
  SESSION_ID="kata-202-validator-$$"
  # Use CancelOrder utterance — this intent has no slots so Lambda is
  # invoked immediately without slot elicitation, avoiding InProgress state.
  # CancelOrder fulfillment goes through the alias Lambda (if configured)
  # and the function returns Fulfilled for any intent.
  RESPONSE=$(aws lexv2-runtime recognize-text \
    --bot-id "$BOT_ID" \
    --bot-alias-id "$ALIAS_ID" \
    --locale-id "en_US" \
    --session-id "$SESSION_ID" \
    --text "Cancel my order" \
    --output json 2>/dev/null)

  RECOGNIZED_INTENT=$(echo "$RESPONSE" | \
    jq -r '.sessionState.intent.name // empty')
  INTENT_STATE=$(echo "$RESPONSE" | \
    jq -r '.sessionState.intent.state // empty')

  if [ "$RECOGNIZED_INTENT" = "CancelOrder" ] && \
     [ "$INTENT_STATE" = "Fulfilled" ]; then
    pass "Bot responds correctly via production alias (CancelOrder — Fulfilled)"
  elif [ "$RECOGNIZED_INTENT" = "CancelOrder" ]; then
    fail "Bot recognized CancelOrder but state is '$INTENT_STATE' — expected Fulfilled. Check Lambda fulfillment and permissions."
  else
    fail "Bot did not route to CancelOrder intent — found: '$RECOGNIZED_INTENT'"
  fi
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
  echo " 🎉 Perfect score! All kata-202 requirements met."
elif [ "$PASS" -ge 6 ]; then
  echo " 🔧 Almost there — review the failed checks above."
else
  echo " 📖 Keep going — consult HINTS.md for guidance."
fi
echo ""