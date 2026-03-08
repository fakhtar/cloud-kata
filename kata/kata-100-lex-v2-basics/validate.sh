#!/bin/bash
# =============================================================================
# CloudKata — kata-100 Validator
# kata:    kata-100
# title:   Amazon Lex V2 Basics: Bots, Intents & Slots
# author:  Faisal Akhtar
# github:  https://github.com/fakhtar
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

BOT_NAME="kata-100-FoodOrderingBot"
LOCALE_ID="en_US"
INTENT_1="OrderFood"
INTENT_2="CancelOrder"
SLOT_NAME="FoodItem"
SLOT_TYPE_NAME="kata-100-FoodItemType"
MIN_UTTERANCES=5
MIN_SLOT_VALUES=4

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
echo " CloudKata Validator — kata-100"
echo " Amazon Lex V2 Basics: Bots, Intents & Slots"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Check 1 — Bot exists
# ------------------------------------------------------------------------------
echo "Checking bot existence..."
BOT_ID=$(aws lexv2-models list-bots \
  --filters name=BotName,values=${BOT_NAME},operator=EQ \
  --query 'botSummaries[0].botId' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$BOT_ID" != "NOT_FOUND" ] && [ "$BOT_ID" != "None" ] && [ -n "$BOT_ID" ]; then
  pass "Bot '${BOT_NAME}' exists (ID: ${BOT_ID})"
else
  fail "Bot '${BOT_NAME}'" "Bot not found — ensure the bot exists with the exact name '${BOT_NAME}'"
  echo ""
  echo "  Cannot continue without a valid bot. Please create the bot and re-run."
  echo ""
  echo "=================================================="
  echo " Results: 0/$((TOTAL)) checks passed (0%)"
  echo "=================================================="
  exit 1
fi

# ------------------------------------------------------------------------------
# Check 2 — Bot language is en_US
# ------------------------------------------------------------------------------
echo "Checking bot language configuration..."
LOCALE_STATUS=$(aws lexv2-models describe-bot-locale \
  --bot-id "$BOT_ID" \
  --bot-version "DRAFT" \
  --locale-id "$LOCALE_ID" \
  --query 'botLocaleStatus' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$LOCALE_STATUS" != "NOT_FOUND" ] && [ "$LOCALE_STATUS" != "None" ] && [ -n "$LOCALE_STATUS" ]; then
  pass "Bot language is configured for ${LOCALE_ID}"
else
  fail "Bot language" "Locale '${LOCALE_ID}' (English US) not found on bot — ensure the bot is configured with English (US)"
fi

# ------------------------------------------------------------------------------
# Check 3 — Bot status is Available
# ------------------------------------------------------------------------------
echo "Checking bot status..."
BOT_STATUS=$(aws lexv2-models describe-bot \
  --bot-id "$BOT_ID" \
  --query 'botStatus' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$BOT_STATUS" = "Available" ]; then
  pass "Bot status is Available"
else
  fail "Bot status" "Expected 'Available' but got '${BOT_STATUS}' — build the bot locale to make it Available"
fi

# ------------------------------------------------------------------------------
# Check 4 — Intent OrderFood exists with sufficient utterances
# ------------------------------------------------------------------------------
echo "Checking intent '${INTENT_1}'..."
INTENT_1_ID=$(aws lexv2-models list-intents \
  --bot-id "$BOT_ID" \
  --bot-version "DRAFT" \
  --locale-id "$LOCALE_ID" \
  --filters name=IntentName,values=${INTENT_1},operator=EQ \
  --query 'intentSummaries[0].intentId' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$INTENT_1_ID" != "NOT_FOUND" ] && [ "$INTENT_1_ID" != "None" ] && [ -n "$INTENT_1_ID" ]; then
  # Check utterance count
  UTTERANCE_COUNT=$(aws lexv2-models describe-intent \
    --bot-id "$BOT_ID" \
    --bot-version "DRAFT" \
    --locale-id "$LOCALE_ID" \
    --intent-id "$INTENT_1_ID" \
    --query 'length(sampleUtterances)' \
    --output text 2>/dev/null || echo "0")

  if [ "$UTTERANCE_COUNT" -ge "$MIN_UTTERANCES" ] 2>/dev/null; then
    pass "Intent '${INTENT_1}' exists with ${UTTERANCE_COUNT} sample utterances (minimum: ${MIN_UTTERANCES})"
  else
    fail "Intent '${INTENT_1}' utterances" "Found ${UTTERANCE_COUNT} utterances but minimum is ${MIN_UTTERANCES} — add more sample utterances to '${INTENT_1}'"
  fi
else
  fail "Intent '${INTENT_1}'" "Intent not found — ensure an intent named exactly '${INTENT_1}' exists on the bot"
fi

# ------------------------------------------------------------------------------
# Check 5 — Intent CancelOrder exists with sufficient utterances
# ------------------------------------------------------------------------------
echo "Checking intent '${INTENT_2}'..."
INTENT_2_ID=$(aws lexv2-models list-intents \
  --bot-id "$BOT_ID" \
  --bot-version "DRAFT" \
  --locale-id "$LOCALE_ID" \
  --filters name=IntentName,values=${INTENT_2},operator=EQ \
  --query 'intentSummaries[0].intentId' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$INTENT_2_ID" != "NOT_FOUND" ] && [ "$INTENT_2_ID" != "None" ] && [ -n "$INTENT_2_ID" ]; then
  # Check utterance count
  UTTERANCE_COUNT=$(aws lexv2-models describe-intent \
    --bot-id "$BOT_ID" \
    --bot-version "DRAFT" \
    --locale-id "$LOCALE_ID" \
    --intent-id "$INTENT_2_ID" \
    --query 'length(sampleUtterances)' \
    --output text 2>/dev/null || echo "0")

  if [ "$UTTERANCE_COUNT" -ge "$MIN_UTTERANCES" ] 2>/dev/null; then
    pass "Intent '${INTENT_2}' exists with ${UTTERANCE_COUNT} sample utterances (minimum: ${MIN_UTTERANCES})"
  else
    fail "Intent '${INTENT_2}' utterances" "Found ${UTTERANCE_COUNT} utterances but minimum is ${MIN_UTTERANCES} — add more sample utterances to '${INTENT_2}'"
  fi
else
  fail "Intent '${INTENT_2}'" "Intent not found — ensure an intent named exactly '${INTENT_2}' exists on the bot"
fi

# ------------------------------------------------------------------------------
# Check 6 — Slot FoodItem exists on OrderFood intent
# ------------------------------------------------------------------------------
echo "Checking slot '${SLOT_NAME}' on intent '${INTENT_1}'..."
if [ "$INTENT_1_ID" != "NOT_FOUND" ] && [ "$INTENT_1_ID" != "None" ] && [ -n "$INTENT_1_ID" ]; then
  SLOT_ID=$(aws lexv2-models list-slots \
    --bot-id "$BOT_ID" \
    --bot-version "DRAFT" \
    --locale-id "$LOCALE_ID" \
    --intent-id "$INTENT_1_ID" \
    --filters name=SlotName,values=${SLOT_NAME},operator=EQ \
    --query 'slotSummaries[0].slotId' \
    --output text 2>/dev/null || echo "NOT_FOUND")

  if [ "$SLOT_ID" != "NOT_FOUND" ] && [ "$SLOT_ID" != "None" ] && [ -n "$SLOT_ID" ]; then
    pass "Slot '${SLOT_NAME}' exists on intent '${INTENT_1}'"
  else
    fail "Slot '${SLOT_NAME}'" "Slot not found on intent '${INTENT_1}' — ensure a slot named exactly '${SLOT_NAME}' exists"
  fi
else
  fail "Slot '${SLOT_NAME}'" "Cannot check slot — intent '${INTENT_1}' was not found"
fi

# ------------------------------------------------------------------------------
# Check 7 — Custom slot type kata-100-FoodItemType exists with sufficient values
# ------------------------------------------------------------------------------
echo "Checking custom slot type '${SLOT_TYPE_NAME}'..."
SLOT_TYPE_ID=$(aws lexv2-models list-slot-types \
  --bot-id "$BOT_ID" \
  --bot-version "DRAFT" \
  --locale-id "$LOCALE_ID" \
  --filters name=SlotTypeName,values=${SLOT_TYPE_NAME},operator=EQ \
  --query 'slotTypeSummaries[0].slotTypeId' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$SLOT_TYPE_ID" != "NOT_FOUND" ] && [ "$SLOT_TYPE_ID" != "None" ] && [ -n "$SLOT_TYPE_ID" ]; then
  # Check value count
  VALUE_COUNT=$(aws lexv2-models describe-slot-type \
    --bot-id "$BOT_ID" \
    --bot-version "DRAFT" \
    --locale-id "$LOCALE_ID" \
    --slot-type-id "$SLOT_TYPE_ID" \
    --query 'length(slotTypeValues)' \
    --output text 2>/dev/null || echo "0")

  if [ "$VALUE_COUNT" -ge "$MIN_SLOT_VALUES" ] 2>/dev/null; then
    pass "Custom slot type '${SLOT_TYPE_NAME}' exists with ${VALUE_COUNT} values (minimum: ${MIN_SLOT_VALUES})"
  else
    fail "Custom slot type '${SLOT_TYPE_NAME}' values" "Found ${VALUE_COUNT} values but minimum is ${MIN_SLOT_VALUES} — add more values to '${SLOT_TYPE_NAME}'"
  fi
else
  fail "Custom slot type '${SLOT_TYPE_NAME}'" "Slot type not found — ensure a custom slot type named exactly '${SLOT_TYPE_NAME}' exists"
fi

# ------------------------------------------------------------------------------
# Check 8 — Bot responds correctly to test utterances
# ------------------------------------------------------------------------------
echo "Checking bot responds to test utterances..."

# Build a test session to check utterance routing
# We use the DRAFT version via the runtime API via CloudShell
# Note: lexv2-runtime requires the bot alias ID — we use the built-in
# TestBotAlias for DRAFT version testing

TEST_ALIAS_ID="TSTALIASID"
TEST_SESSION_ID="cloudkata-validator-$(date +%s)"
UTTERANCE_FAILURES=0

declare -A TEST_CASES
TEST_CASES["I want to order a pizza"]="OrderFood"
TEST_CASES["Can I get a burger"]="OrderFood"
TEST_CASES["Cancel my order"]="CancelOrder"
TEST_CASES["I want to cancel"]="CancelOrder"

for UTTERANCE in "${!TEST_CASES[@]}"; do
  EXPECTED_INTENT="${TEST_CASES[$UTTERANCE]}"
  RECOGNIZED_INTENT=$(aws lexv2-runtime recognize-text \
    --bot-id "$BOT_ID" \
    --bot-alias-id "$TEST_ALIAS_ID" \
    --locale-id "$LOCALE_ID" \
    --session-id "$TEST_SESSION_ID" \
    --text "$UTTERANCE" \
    --query 'interpretations[0].intent.name' \
    --output text 2>/dev/null || echo "ERROR")

  if [ "$RECOGNIZED_INTENT" = "$EXPECTED_INTENT" ]; then
    echo "   ✔ '${UTTERANCE}' → ${RECOGNIZED_INTENT}"
  else
    echo "   ✘ '${UTTERANCE}' → Expected '${EXPECTED_INTENT}' but got '${RECOGNIZED_INTENT}'"
    UTTERANCE_FAILURES=$((UTTERANCE_FAILURES + 1))
  fi
done

if [ "$UTTERANCE_FAILURES" -eq 0 ]; then
  pass "Bot responds correctly to all test utterances"
else
  fail "Bot test utterances" "${UTTERANCE_FAILURES} utterance(s) routed to the wrong intent — review your sample utterances and rebuild the bot"
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
  echo " 🎉 Perfect score! All kata-100 requirements met."
  echo ""
fi

if [ "$FAIL" -gt 0 ]; then
  echo " Review the failed checks above, fix your infrastructure,"
  echo " and re-run this validator."
  echo ""
  exit 1
fi
