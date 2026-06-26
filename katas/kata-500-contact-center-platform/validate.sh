#!/bin/bash
# =============================================================================
# CloudKata — kata-500 Validator
# kata:    kata-500
# title:   Contact Center Platform
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

INSTANCE_ALIAS="kata-500-instance"
BOT_NAME="kata-500-IVRBot"
ALIAS_NAME="kata-500-ProdAlias"
FUNCTION_NAME="kata-500-FulfillmentFunction"
TABLE_NAME="kata-500-CallerDataTable"
FLOW_NAME="kata-500-ContactFlow"
LOG_GROUP_NAME="kata-500-ContactFlowLogs"
ALARM_NAME="kata-500-LambdaErrorAlarm"
LOCALE_ID="en_US"
INTENT_1="CheckOrderStatus"
INTENT_2="CancelOrder"
SLOT_NAME="OrderId"
MIN_UTTERANCES=5

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
echo " CloudKata Validator — kata-500"
echo " Contact Center Platform"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Check 1 — Connect instance exists and is ACTIVE
# ------------------------------------------------------------------------------
echo "Checking Connect instance..."
INSTANCE_ID=$(aws connect list-instances \
  --query "InstanceSummaryList[?InstanceAlias=='${INSTANCE_ALIAS}'].Id | [0]" \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$INSTANCE_ID" = "NOT_FOUND" ] || [ "$INSTANCE_ID" = "None" ] || [ -z "$INSTANCE_ID" ]; then
  fail "Connect instance '${INSTANCE_ALIAS}'" "Instance not found — ensure a Connect instance with alias '${INSTANCE_ALIAS}' exists"
  echo ""
  echo "  Cannot continue without a valid Connect instance. Please create it and re-run."
  echo ""
  echo "=================================================="
  echo " Results: 0/$((TOTAL + 10)) checks passed (0%)"
  echo "=================================================="
  exit 1
fi

INSTANCE_STATUS=$(aws connect describe-instance \
  --instance-id "$INSTANCE_ID" \
  --query 'Instance.InstanceStatus' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$INSTANCE_STATUS" = "ACTIVE" ]; then
  pass "Connect instance '${INSTANCE_ALIAS}' is ACTIVE (ID: ${INSTANCE_ID})"
else
  fail "Connect instance '${INSTANCE_ALIAS}'" "Expected status 'ACTIVE' but got '${INSTANCE_STATUS}'"
fi

# ------------------------------------------------------------------------------
# Check 2 — Connect instance attributes: inbound, outbound, contact flow logs
# ------------------------------------------------------------------------------
echo "Checking Connect instance attributes..."

INBOUND=$(aws connect describe-instance \
  --instance-id "$INSTANCE_ID" \
  --query 'Instance.InboundCallsEnabled' \
  --output text 2>/dev/null || echo "false")

OUTBOUND=$(aws connect describe-instance \
  --instance-id "$INSTANCE_ID" \
  --query 'Instance.OutboundCallsEnabled' \
  --output text 2>/dev/null || echo "false")

# CONTACT_FLOW_LOGS is not reliably returned by list-instance-attributes.
# describe-instance-attribute (singular) with --attribute-type is the correct API.
FLOW_LOGS=$(aws connect describe-instance-attribute \
  --instance-id "$INSTANCE_ID" \
  --attribute-type CONTACTFLOW_LOGS \
  --query 'Attribute.Value' \
  --output text 2>/dev/null || echo "false")

ATTR_FAILURES=0

# AWS CLI --output text renders JSON booleans as "True"/"False" (capitalised).
# Normalise to lowercase for a single comparison.
INBOUND_LOWER=$(echo "$INBOUND" | tr '[:upper:]' '[:lower:]')
OUTBOUND_LOWER=$(echo "$OUTBOUND" | tr '[:upper:]' '[:lower:]')
FLOW_LOGS_LOWER=$(echo "$FLOW_LOGS" | tr '[:upper:]' '[:lower:]')

if [ "$INBOUND_LOWER" != "true" ]; then
  echo "   ✘ Inbound calls not enabled"
  ATTR_FAILURES=$((ATTR_FAILURES + 1))
fi
if [ "$OUTBOUND_LOWER" != "true" ]; then
  echo "   ✘ Outbound calls not enabled"
  ATTR_FAILURES=$((ATTR_FAILURES + 1))
fi
if [ "$FLOW_LOGS_LOWER" != "true" ]; then
  echo "   ✘ Contact flow logs not enabled"
  ATTR_FAILURES=$((ATTR_FAILURES + 1))
fi

if [ "$ATTR_FAILURES" -eq 0 ]; then
  pass "Connect instance has inbound, outbound, and contact flow logs enabled"
else
  fail "Connect instance attributes" "${ATTR_FAILURES} attribute(s) not correctly configured — check inbound/outbound calling and contact flow log settings"
fi

# ------------------------------------------------------------------------------
# Check 3 — Lex V2 bot exists, locale is Built
# ------------------------------------------------------------------------------
echo "Checking Lex V2 bot '${BOT_NAME}'..."
BOT_ID=$(aws lexv2-models list-bots \
  --filters name=BotName,values="${BOT_NAME}",operator=EQ \
  --query 'botSummaries[0].botId' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$BOT_ID" = "NOT_FOUND" ] || [ "$BOT_ID" = "None" ] || [ -z "$BOT_ID" ]; then
  fail "Lex V2 bot '${BOT_NAME}'" "Bot not found — ensure a Lex V2 bot named exactly '${BOT_NAME}' exists"
else
  LOCALE_STATUS=$(aws lexv2-models describe-bot-locale \
    --bot-id "$BOT_ID" \
    --bot-version "DRAFT" \
    --locale-id "$LOCALE_ID" \
    --query 'botLocaleStatus' \
    --output text 2>/dev/null || echo "NOT_FOUND")

  if [ "$LOCALE_STATUS" = "Built" ]; then
    pass "Lex V2 bot '${BOT_NAME}' exists and locale is Built (ID: ${BOT_ID})"
  else
    fail "Lex V2 bot '${BOT_NAME}'" "Bot found but locale status is '${LOCALE_STATUS}' — build the bot locale to reach 'Built' status"
  fi
fi

# ------------------------------------------------------------------------------
# Check 4 — Intents CheckOrderStatus and CancelOrder exist with enough utterances
#           and OrderId slot exists on CheckOrderStatus
# ------------------------------------------------------------------------------
echo "Checking intents and slots..."
INTENT_FAILURES=0

if [ "$BOT_ID" != "NOT_FOUND" ] && [ "$BOT_ID" != "None" ] && [ -n "$BOT_ID" ]; then
  for INTENT_NAME in "$INTENT_1" "$INTENT_2"; do
    INTENT_ID=$(aws lexv2-models list-intents \
      --bot-id "$BOT_ID" \
      --bot-version "DRAFT" \
      --locale-id "$LOCALE_ID" \
      --filters name=IntentName,values="${INTENT_NAME}",operator=EQ \
      --query 'intentSummaries[0].intentId' \
      --output text 2>/dev/null || echo "NOT_FOUND")

    if [ "$INTENT_ID" = "NOT_FOUND" ] || [ "$INTENT_ID" = "None" ] || [ -z "$INTENT_ID" ]; then
      echo "   ✘ Intent '${INTENT_NAME}' not found"
      INTENT_FAILURES=$((INTENT_FAILURES + 1))
    else
      UTTERANCE_COUNT=$(aws lexv2-models describe-intent \
        --bot-id "$BOT_ID" \
        --bot-version "DRAFT" \
        --locale-id "$LOCALE_ID" \
        --intent-id "$INTENT_ID" \
        --query 'length(sampleUtterances)' \
        --output text 2>/dev/null || echo "0")

      if [ "$UTTERANCE_COUNT" -ge "$MIN_UTTERANCES" ] 2>/dev/null; then
        echo "   ✔ Intent '${INTENT_NAME}' exists with ${UTTERANCE_COUNT} utterances"
      else
        echo "   ✘ Intent '${INTENT_NAME}' has ${UTTERANCE_COUNT} utterances (minimum: ${MIN_UTTERANCES})"
        INTENT_FAILURES=$((INTENT_FAILURES + 1))
      fi

      # Check for OrderId slot on CheckOrderStatus only
      if [ "$INTENT_NAME" = "$INTENT_1" ]; then
        SLOT_ID=$(aws lexv2-models list-slots \
          --bot-id "$BOT_ID" \
          --bot-version "DRAFT" \
          --locale-id "$LOCALE_ID" \
          --intent-id "$INTENT_ID" \
          --filters name=SlotName,values="${SLOT_NAME}",operator=EQ \
          --query 'slotSummaries[0].slotId' \
          --output text 2>/dev/null || echo "NOT_FOUND")

        if [ "$SLOT_ID" = "NOT_FOUND" ] || [ "$SLOT_ID" = "None" ] || [ -z "$SLOT_ID" ]; then
          echo "   ✘ Slot '${SLOT_NAME}' not found on intent '${INTENT_1}'"
          INTENT_FAILURES=$((INTENT_FAILURES + 1))
        else
          echo "   ✔ Slot '${SLOT_NAME}' exists on intent '${INTENT_1}'"
        fi
      fi
    fi
  done
fi

if [ "$INTENT_FAILURES" -eq 0 ]; then
  pass "Intents '${INTENT_1}' and '${INTENT_2}' exist with sufficient utterances and slot '${SLOT_NAME}' is present"
else
  fail "Intents and slots" "${INTENT_FAILURES} issue(s) found — review intent names, utterance counts, and slot configuration"
fi

# ------------------------------------------------------------------------------
# Check 5 — Bot alias kata-500-ProdAlias exists with en_US enabled
# ------------------------------------------------------------------------------
echo "Checking bot alias '${ALIAS_NAME}'..."
if [ -n "$BOT_ID" ] && [ "$BOT_ID" != "NOT_FOUND" ] && [ "$BOT_ID" != "None" ]; then
  ALIAS_ID=$(aws lexv2-models list-bot-aliases \
    --bot-id "$BOT_ID" \
    --query "botAliasSummaries[?botAliasName=='${ALIAS_NAME}'].botAliasId | [0]" \
    --output text 2>/dev/null || echo "NOT_FOUND")

  if [ "$ALIAS_ID" = "NOT_FOUND" ] || [ "$ALIAS_ID" = "None" ] || [ -z "$ALIAS_ID" ]; then
    fail "Bot alias '${ALIAS_NAME}'" "Alias not found — ensure a bot alias named exactly '${ALIAS_NAME}' exists"
  else
    LOCALE_ENABLED=$(aws lexv2-models describe-bot-alias \
      --bot-id "$BOT_ID" \
      --bot-alias-id "$ALIAS_ID" \
      --query "botAliasLocaleSettings.${LOCALE_ID}.enabled" \
      --output text 2>/dev/null || echo "false")

    if [ "$LOCALE_ENABLED" = "True" ] || [ "$LOCALE_ENABLED" = "true" ]; then
      pass "Bot alias '${ALIAS_NAME}' exists with en_US enabled (ID: ${ALIAS_ID})"
    else
      fail "Bot alias '${ALIAS_NAME}'" "Alias found but en_US locale is not enabled — enable the en_US locale on the alias"
    fi
  fi
else
  fail "Bot alias '${ALIAS_NAME}'" "Cannot check alias — bot '${BOT_NAME}' was not found"
fi

# ------------------------------------------------------------------------------
# Check 6 — Lambda function exists and is configured correctly
# ------------------------------------------------------------------------------
echo "Checking Lambda function '${FUNCTION_NAME}'..."
FUNCTION_STATE=$(aws lambda get-function \
  --function-name "$FUNCTION_NAME" \
  --query 'Configuration.State' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$FUNCTION_STATE" = "NOT_FOUND" ] || [ "$FUNCTION_STATE" = "None" ]; then
  fail "Lambda function '${FUNCTION_NAME}'" "Function not found — ensure a Lambda function named exactly '${FUNCTION_NAME}' exists"
else
  FUNCTION_TIMEOUT=$(aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --query 'Configuration.Timeout' \
    --output text 2>/dev/null || echo "0")

  LAMBDA_ROLE_ARN=$(aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --query 'Configuration.Role' \
    --output text 2>/dev/null || echo "NOT_FOUND")

  LAMBDA_FAILURES=0

  if [ "$FUNCTION_TIMEOUT" -lt 10 ] 2>/dev/null; then
    echo "   ✘ Timeout is ${FUNCTION_TIMEOUT}s — must be at least 10 seconds"
    LAMBDA_FAILURES=$((LAMBDA_FAILURES + 1))
  else
    echo "   ✔ Timeout is ${FUNCTION_TIMEOUT}s"
  fi

  if [ "$FUNCTION_STATE" = "Active" ]; then
    echo "   ✔ Function state is Active"
  else
    echo "   ✘ Function state is '${FUNCTION_STATE}' (expected Active)"
    LAMBDA_FAILURES=$((LAMBDA_FAILURES + 1))
  fi

  if [ "$LAMBDA_FAILURES" -eq 0 ]; then
    pass "Lambda function '${FUNCTION_NAME}' exists and is configured correctly"
  else
    fail "Lambda function '${FUNCTION_NAME}'" "${LAMBDA_FAILURES} configuration issue(s) — check function state and timeout"
  fi
fi

# ------------------------------------------------------------------------------
# Check 7 — DynamoDB table exists and is ACTIVE
# ------------------------------------------------------------------------------
echo "Checking DynamoDB table '${TABLE_NAME}'..."
TABLE_STATUS=$(aws dynamodb describe-table \
  --table-name "$TABLE_NAME" \
  --query 'Table.TableStatus' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$TABLE_STATUS" = "ACTIVE" ]; then
  pass "DynamoDB table '${TABLE_NAME}' is ACTIVE"
else
  fail "DynamoDB table '${TABLE_NAME}'" "Expected status 'ACTIVE' but got '${TABLE_STATUS}' — ensure the table exists and has finished creating"
fi

# ------------------------------------------------------------------------------
# Check 8 — Contact flow exists in the Connect instance
# ------------------------------------------------------------------------------
echo "Checking contact flow '${FLOW_NAME}'..."
FLOW_ID=$(aws connect list-contact-flows \
  --instance-id "$INSTANCE_ID" \
  --contact-flow-types CONTACT_FLOW \
  --query "ContactFlowSummaryList[?Name=='${FLOW_NAME}'].Id | [0]" \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$FLOW_ID" != "NOT_FOUND" ] && [ "$FLOW_ID" != "None" ] && [ -n "$FLOW_ID" ]; then
  pass "Contact flow '${FLOW_NAME}' exists in Connect instance (ID: ${FLOW_ID})"
else
  fail "Contact flow '${FLOW_NAME}'" "Contact flow not found in instance '${INSTANCE_ALIAS}' — ensure a contact flow named exactly '${FLOW_NAME}' exists"
fi

# ------------------------------------------------------------------------------
# Check 9 — CloudWatch log group exists with 30-day retention
# ------------------------------------------------------------------------------
echo "Checking CloudWatch log group '${LOG_GROUP_NAME}'..."
LOG_GROUP_RETENTION=$(aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --query "logGroups[?logGroupName=='${LOG_GROUP_NAME}'].retentionInDays | [0]" \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$LOG_GROUP_RETENTION" = "NOT_FOUND" ] || [ "$LOG_GROUP_RETENTION" = "None" ] || [ -z "$LOG_GROUP_RETENTION" ]; then
  fail "CloudWatch log group '${LOG_GROUP_NAME}'" "Log group not found — ensure a log group named exactly '${LOG_GROUP_NAME}' exists"
elif [ "$LOG_GROUP_RETENTION" = "30" ]; then
  pass "CloudWatch log group '${LOG_GROUP_NAME}' exists with 30-day retention"
else
  fail "CloudWatch log group '${LOG_GROUP_NAME}'" "Log group found but retention is ${LOG_GROUP_RETENTION} days — set retention to 30 days"
fi

# ------------------------------------------------------------------------------
# Check 10 — CloudWatch alarm exists and is evaluable
# ------------------------------------------------------------------------------
echo "Checking CloudWatch alarm '${ALARM_NAME}'..."
ALARM_STATE=$(aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[0].StateValue' \
  --output text 2>/dev/null || echo "NOT_FOUND")

ALARM_THRESHOLD=$(aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[0].Threshold' \
  --output text 2>/dev/null || echo "NOT_FOUND")

ALARM_COMPARISON=$(aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[0].ComparisonOperator' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$ALARM_STATE" = "NOT_FOUND" ] || [ "$ALARM_STATE" = "None" ]; then
  fail "CloudWatch alarm '${ALARM_NAME}'" "Alarm not found — ensure an alarm named exactly '${ALARM_NAME}' exists"
elif [ "$ALARM_STATE" = "INSUFFICIENT_DATA" ]; then
  fail "CloudWatch alarm '${ALARM_NAME}'" "Alarm is in INSUFFICIENT_DATA state — check the metric namespace, dimensions, and function name are correctly configured"
else
  # Threshold must be >= 1 and comparison must catch errors >= 1
  ALARM_OK=true
  if [ "$ALARM_COMPARISON" != "GreaterThanOrEqualToThreshold" ] && [ "$ALARM_COMPARISON" != "GreaterThanThreshold" ]; then
    echo "   ✘ Comparison operator '${ALARM_COMPARISON}' will not correctly catch errors"
    ALARM_OK=false
  fi
  # Threshold check: must be <= 1 so a single error triggers it
  THRESHOLD_INT=$(echo "$ALARM_THRESHOLD" | cut -d'.' -f1)
  if [ -n "$THRESHOLD_INT" ] && [ "$THRESHOLD_INT" -gt 1 ] 2>/dev/null; then
    echo "   ✘ Threshold ${ALARM_THRESHOLD} is too high — alarm must trigger on the first error"
    ALARM_OK=false
  fi

  if [ "$ALARM_OK" = "true" ]; then
    pass "CloudWatch alarm '${ALARM_NAME}' is correctly configured (state: ${ALARM_STATE})"
  else
    fail "CloudWatch alarm '${ALARM_NAME}'" "Alarm configuration does not satisfy requirements — review comparison operator and threshold"
  fi
fi

# ------------------------------------------------------------------------------
# Check 11 — Integration: Lex bot associated with Connect instance
# ------------------------------------------------------------------------------
echo "Checking integration: Lex bot associated with Connect instance..."
BOT_ALIAS_ARN=$(aws connect list-bots \
  --instance-id "$INSTANCE_ID" \
  --lex-version V2 \
  --query "LexBots[?LexV2Bot.AliasArn != null].LexV2Bot.AliasArn | [0]" \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$BOT_ALIAS_ARN" != "NOT_FOUND" ] && [ "$BOT_ALIAS_ARN" != "None" ] && [ -n "$BOT_ALIAS_ARN" ]; then
  # Confirm the ARN contains the expected bot name
  if echo "$BOT_ALIAS_ARN" | grep -q "$BOT_ID"; then
    pass "Integration: '${BOT_NAME}' is associated with Connect instance '${INSTANCE_ALIAS}'"
  else
    fail "Integration: Lex bot association" "A Lex V2 bot is associated but its ARN does not reference bot ID '${BOT_ID}' — ensure the correct bot is associated: ${BOT_ALIAS_ARN}"
  fi
else
  fail "Integration: Lex bot association" "No Lex V2 bot is associated with instance '${INSTANCE_ALIAS}' — associate '${BOT_NAME}' with the Connect instance"
fi

# ------------------------------------------------------------------------------
# Check 12 — Integration: Lambda hook configured on kata-500-ProdAlias
# ------------------------------------------------------------------------------
echo "Checking integration: Lambda hook on '${ALIAS_NAME}'..."
if [ -n "$BOT_ID" ] && [ "$BOT_ID" != "NOT_FOUND" ] && [ "$BOT_ID" != "None" ] && \
   [ -n "$ALIAS_ID" ] && [ "$ALIAS_ID" != "NOT_FOUND" ] && [ "$ALIAS_ID" != "None" ]; then
  HOOK_ARN=$(aws lexv2-models describe-bot-alias \
    --bot-id "$BOT_ID" \
    --bot-alias-id "$ALIAS_ID" \
    --query "botAliasLocaleSettings.${LOCALE_ID}.codeHookSpecification.lambdaCodeHook.lambdaARN" \
    --output text 2>/dev/null || echo "NOT_FOUND")

  if [ "$HOOK_ARN" != "NOT_FOUND" ] && [ "$HOOK_ARN" != "None" ] && [ -n "$HOOK_ARN" ]; then
    if echo "$HOOK_ARN" | grep -q "${FUNCTION_NAME}"; then
      pass "Integration: '${FUNCTION_NAME}' is the Lambda code hook on '${ALIAS_NAME}'"
    else
      fail "Integration: Lambda hook" "A Lambda hook is configured but does not reference '${FUNCTION_NAME}' — found: ${HOOK_ARN}"
    fi
  else
    fail "Integration: Lambda hook" "No Lambda code hook configured on alias '${ALIAS_NAME}' for locale ${LOCALE_ID} — add '${FUNCTION_NAME}' as the code hook"
  fi
else
  fail "Integration: Lambda hook" "Cannot check Lambda hook — bot or alias was not found"
fi

# ------------------------------------------------------------------------------
# Check 13 — Integration: Lambda execution role has DynamoDB access
# ------------------------------------------------------------------------------
echo "Checking integration: Lambda execution role has DynamoDB access..."
if [ -n "$LAMBDA_ROLE_ARN" ] && [ "$LAMBDA_ROLE_ARN" != "NOT_FOUND" ]; then
  ROLE_NAME=$(echo "$LAMBDA_ROLE_ARN" | sed 's|.*/||')

  # Check attached managed policies for DynamoDB
  DYNAMO_MANAGED=$(aws iam list-attached-role-policies \
    --role-name "$ROLE_NAME" \
    --query "AttachedPolicies[?contains(PolicyName, 'DynamoDB')].PolicyName | [0]" \
    --output text 2>/dev/null || echo "NOT_FOUND")

  # Check inline policies for DynamoDB
  DYNAMO_INLINE=$(aws iam list-role-policies \
    --role-name "$ROLE_NAME" \
    --query "PolicyNames[?contains(@, 'DynamoDB') || contains(@, 'dynamo')] | [0]" \
    --output text 2>/dev/null || echo "NOT_FOUND")

  # Check for AmazonDynamoDBFullAccess or similar by looking at policy content
  # Fall back to checking if any inline policy references the table
  DYNAMO_TABLE_INLINE=$(aws iam list-role-policies \
    --role-name "$ROLE_NAME" \
    --output text 2>/dev/null | grep -i "dynamo" || echo "")

  if [ "$DYNAMO_MANAGED" != "NOT_FOUND" ] && [ "$DYNAMO_MANAGED" != "None" ] && [ -n "$DYNAMO_MANAGED" ]; then
    pass "Integration: Lambda execution role '${ROLE_NAME}' has DynamoDB managed policy: ${DYNAMO_MANAGED}"
  elif [ "$DYNAMO_INLINE" != "NOT_FOUND" ] && [ "$DYNAMO_INLINE" != "None" ] && [ -n "$DYNAMO_INLINE" ]; then
    pass "Integration: Lambda execution role '${ROLE_NAME}' has DynamoDB inline policy: ${DYNAMO_INLINE}"
  elif [ -n "$DYNAMO_TABLE_INLINE" ]; then
    pass "Integration: Lambda execution role '${ROLE_NAME}' has a policy referencing DynamoDB"
  else
    fail "Integration: Lambda execution role DynamoDB access" "No DynamoDB policy found on role '${ROLE_NAME}' — ensure the execution role grants access to '${TABLE_NAME}'"
  fi
else
  fail "Integration: Lambda execution role DynamoDB access" "Cannot check role — Lambda function or its role ARN was not found"
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
  echo " 🎉 Perfect score! All kata-500 requirements met."
  echo ""
fi

if [ "$FAIL" -gt 0 ]; then
  echo " Review the failed checks above, fix your infrastructure,"
  echo " and re-run this validator."
  echo ""
  exit 1
fi