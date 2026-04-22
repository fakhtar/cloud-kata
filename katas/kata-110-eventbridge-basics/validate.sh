#!/bin/bash

# ==============================================================================
# CloudKata Validator -- kata-110
# EventBridge Basics: Rules, Targets & Scheduling
# ==============================================================================

TOPIC_NAME="kata-110-AlertTopic"
RULE_NAME="kata-110-ScheduledRule"
TARGET_ID="kata-110-AlertTopicTarget"
EXPECTED_SCHEDULE="rate(5 minutes)"

PASS=0
FAIL=0
TOTAL=6

pass() { echo "✅ PASS -- $1"; ((PASS++)); }
fail() { echo "❌ FAIL -- $1: $2"; ((FAIL++)); }

echo ""
echo "=================================================="
echo " CloudKata Validator -- kata-110"
echo " EventBridge Basics: Rules, Targets & Scheduling"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Check 1 -- SNS topic exists
# ------------------------------------------------------------------------------
echo "Checking SNS topic..."
TOPIC_ARN=$(aws sns list-topics \
  --query "Topics[?ends_with(TopicArn, ':${TOPIC_NAME}')].TopicArn" \
  --output text 2>/dev/null | head -1)

if [ -n "$TOPIC_ARN" ] && [ "$TOPIC_ARN" != "None" ]; then
  pass "SNS topic '$TOPIC_NAME' exists"
else
  fail "SNS topic '$TOPIC_NAME' not found" \
    "Create an SNS standard topic named exactly '$TOPIC_NAME' in this region"
  TOPIC_ARN=""
fi

# ------------------------------------------------------------------------------
# Check 2 -- EventBridge rule exists
# ------------------------------------------------------------------------------
echo "Checking EventBridge rule..."
RULE_JSON=$(aws events describe-rule \
  --name "$RULE_NAME" \
  --output json 2>/dev/null)

RULE_FOUND=$(echo "$RULE_JSON" | jq -r '.Name // empty' 2>/dev/null)

if [ "$RULE_FOUND" = "$RULE_NAME" ]; then
  pass "EventBridge rule '$RULE_NAME' exists"
else
  fail "EventBridge rule '$RULE_NAME' not found" \
    "Create a scheduled EventBridge rule named exactly '$RULE_NAME' on the default event bus"
  echo ""
  echo "=================================================="
  PCT=$(( (PASS * 100) / TOTAL ))
  echo " Results: $PASS/$TOTAL checks passed ($PCT%)"
  echo "=================================================="
  echo " 📖 Keep going -- consult HINTS.md for guidance."
  echo ""
  exit 1
fi

# ------------------------------------------------------------------------------
# Check 3 -- Rule schedule expression is correct
# ------------------------------------------------------------------------------
echo "Checking schedule expression..."
ACTUAL_SCHEDULE=$(echo "$RULE_JSON" | jq -r '.ScheduleExpression // empty' 2>/dev/null)

if [ "$ACTUAL_SCHEDULE" = "$EXPECTED_SCHEDULE" ]; then
  pass "Rule schedule expression is '$EXPECTED_SCHEDULE'"
else
  fail "Rule schedule expression is '$ACTUAL_SCHEDULE'" \
    "Expected '$EXPECTED_SCHEDULE' -- update the rule schedule"
fi

# ------------------------------------------------------------------------------
# Check 4 -- Rule state is ENABLED
# ------------------------------------------------------------------------------
echo "Checking rule state..."
RULE_STATE=$(echo "$RULE_JSON" | jq -r '.State // empty' 2>/dev/null)

if [ "$RULE_STATE" = "ENABLED" ]; then
  pass "Rule state is ENABLED"
else
  fail "Rule state is '$RULE_STATE'" \
    "The rule must be in an ENABLED state -- enable it in the EventBridge console"
fi

# ------------------------------------------------------------------------------
# Check 5 -- Rule target is the SNS topic
# ------------------------------------------------------------------------------
echo "Checking rule target..."
if [ -n "$TOPIC_ARN" ]; then
  TARGET_ARN=$(aws events list-targets-by-rule \
    --rule "$RULE_NAME" \
    --query "Targets[?Arn=='${TOPIC_ARN}'].Arn" \
    --output text 2>/dev/null | head -1)

  if [ "$TARGET_ARN" = "$TOPIC_ARN" ]; then
    pass "Rule target is set to '$TOPIC_NAME'"
  else
    fail "Rule target is not set to '$TOPIC_NAME'" \
      "Add '$TOPIC_NAME' as a target of '$RULE_NAME' with target ID '$TARGET_ID'"
  fi
else
  fail "Cannot check rule target" \
    "SNS topic '$TOPIC_NAME' was not found -- create it first"
fi

# ------------------------------------------------------------------------------
# Check 6 -- SNS topic policy grants EventBridge publish permission
# ------------------------------------------------------------------------------
echo "Checking SNS topic policy..."
if [ -n "$TOPIC_ARN" ]; then
  POLICY_RAW=$(aws sns get-topic-attributes \
    --topic-arn "$TOPIC_ARN" \
    --query 'Attributes.Policy' \
    --output text 2>/dev/null)

  EB_ALLOWED=$(echo "$POLICY_RAW" | jq -r '
    .Statement[]
    | select(
        (.Effect == "Allow") and
        (
          (.Principal.Service == "events.amazonaws.com") or
          ((.Principal.Service // []) | arrays | any(. == "events.amazonaws.com"))
        ) and
        (
          (.Action == "sns:Publish") or
          ((.Action // []) | arrays | any(. == "sns:Publish"))
        )
      )
    | .Effect' 2>/dev/null | head -1)

  if [ "$EB_ALLOWED" = "Allow" ]; then
    pass "SNS topic policy grants EventBridge publish permission"
  else
    fail "SNS topic policy does not grant EventBridge publish permission" \
      "Add a resource-based policy to '$TOPIC_NAME' allowing events.amazonaws.com to sns:Publish"
  fi
else
  fail "Cannot check SNS topic policy" \
    "SNS topic '$TOPIC_NAME' was not found -- create it first"
fi

# ------------------------------------------------------------------------------
# Results
# ------------------------------------------------------------------------------
PCT=$(( (PASS * 100) / TOTAL ))

echo ""
echo "=================================================="
echo " Results: $PASS/$TOTAL checks passed ($PCT%)"
echo "=================================================="

if [ "$PASS" -eq "$TOTAL" ]; then
  echo " 🎉 Perfect score! All kata-110 requirements met."
elif [ "$PASS" -ge 4 ]; then
  echo " 🔧 Almost there -- review the failed checks above."
else
  echo " 📖 Keep going -- consult HINTS.md for guidance."
fi
echo ""