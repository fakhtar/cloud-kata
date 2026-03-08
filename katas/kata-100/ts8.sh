#!/bin/bash
# =============================================================================
# CloudKata — kata-100 Check 8 Troubleshooter
# Diagnoses issues with the bot runtime utterance test
# =============================================================================
#
# Usage:
#   chmod +x troubleshoot-check8.sh
#   ./troubleshoot-check8.sh
#
# Copy the full output and share it for diagnosis.
# =============================================================================

BOT_NAME="kata-100-FoodOrderingBot"
LOCALE_ID="en_US"

echo ""
echo "=================================================="
echo " CloudKata — Check 8 Troubleshooter"
echo " kata-100-FoodOrderingBot Runtime Diagnostics"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Step 1 — Confirm AWS identity and region
# ------------------------------------------------------------------------------
echo "--- Step 1: AWS Identity & Region ---"
aws sts get-caller-identity 2>&1
echo ""
echo "Current region:"
aws configure get region 2>&1
echo ""

# ------------------------------------------------------------------------------
# Step 2 — Look up bot ID
# ------------------------------------------------------------------------------
echo "--- Step 2: Bot Lookup ---"
BOT_ID=$(aws lexv2-models list-bots \
  --filters name=BotName,values=${BOT_NAME},operator=EQ \
  --query 'botSummaries[0].botId' \
  --output text 2>/dev/null || echo "NOT_FOUND")
echo "Bot ID: $BOT_ID"
echo ""

if [ "$BOT_ID" = "NOT_FOUND" ] || [ "$BOT_ID" = "None" ] || [ -z "$BOT_ID" ]; then
  echo "ERROR: Bot not found. Cannot continue troubleshooting."
  exit 1
fi

# ------------------------------------------------------------------------------
# Step 3 — Check bot status
# ------------------------------------------------------------------------------
echo "--- Step 3: Bot Status ---"
aws lexv2-models describe-bot \
  --bot-id "$BOT_ID" \
  --query '{BotName: botName, BotStatus: botStatus, CreationDate: creationDateTime}' \
  --output table 2>&1
echo ""

# ------------------------------------------------------------------------------
# Step 4 — Check bot locale status
# ------------------------------------------------------------------------------
echo "--- Step 4: Bot Locale Status ---"
aws lexv2-models describe-bot-locale \
  --bot-id "$BOT_ID" \
  --bot-version "DRAFT" \
  --locale-id "$LOCALE_ID" \
  --query '{LocaleId: localeId, Status: botLocaleStatus, LastBuildSubmitted: lastBuildSubmittedDateTime}' \
  --output table 2>&1
echo ""

# ------------------------------------------------------------------------------
# Step 5 — List all bot aliases
# ------------------------------------------------------------------------------
echo "--- Step 5: All Bot Aliases ---"
aws lexv2-models list-bot-aliases \
  --bot-id "$BOT_ID" \
  --query 'botAliasSummaries[*].{AliasId: botAliasId, AliasName: botAliasName, BotVersion: botVersion, Status: botAliasStatus}' \
  --output table 2>&1
echo ""

# ------------------------------------------------------------------------------
# Step 6 — Attempt to resolve TestBotAlias ID
# ------------------------------------------------------------------------------
echo "--- Step 6: TestBotAlias Lookup ---"
TEST_ALIAS_ID=$(aws lexv2-models list-bot-aliases \
  --bot-id "$BOT_ID" \
  --query "botAliasSummaries[?botAliasName=='TestBotAlias'].botAliasId | [0]" \
  --output text 2>/dev/null || echo "NOT_FOUND")
echo "TestBotAlias ID: $TEST_ALIAS_ID"
echo ""

# ------------------------------------------------------------------------------
# Step 7 — Attempt a single recognize-text call with full raw output
# ------------------------------------------------------------------------------
echo "--- Step 7: Raw recognize-text Response ---"
echo "Utterance: 'I want to order a pizza'"
echo ""

if [ "$TEST_ALIAS_ID" = "NOT_FOUND" ] || [ "$TEST_ALIAS_ID" = "None" ] || [ -z "$TEST_ALIAS_ID" ]; then
  echo "Skipping recognize-text — TestBotAlias ID not found."
  echo "Trying with hardcoded TSTALIASID as fallback..."
  TEST_ALIAS_ID="TSTALIASID"
fi

aws lexv2-runtime recognize-text \
  --bot-id "$BOT_ID" \
  --bot-alias-id "$TEST_ALIAS_ID" \
  --locale-id "$LOCALE_ID" \
  --session-id "cloudkata-troubleshoot-$(date +%s)" \
  --text "I want to order a pizza" \
  2>&1
echo ""

# ------------------------------------------------------------------------------
# Step 8 — Check IAM permissions for lexv2-runtime
# ------------------------------------------------------------------------------
echo "--- Step 8: Check lexv2-runtime IAM Permissions ---"
echo "Checking if current identity can call lexv2-runtime recognize-text..."
aws lexv2-runtime recognize-text \
  --bot-id "$BOT_ID" \
  --bot-alias-id "TSTALIASID" \
  --locale-id "$LOCALE_ID" \
  --session-id "cloudkata-iam-check-$(date +%s)" \
  --text "test" \
  --debug 2>&1 | grep -E "DEBUG|ERROR|botocore|endpoint|credential|AccessDenied|not authorized" | head -20
echo ""

echo "=================================================="
echo " Troubleshooting output complete."
echo " Copy everything above this line and share for diagnosis."
echo "=================================================="
echo ""