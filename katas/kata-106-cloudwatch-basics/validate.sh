#!/bin/bash

# ==============================================================================
# CloudKata Validator — kata-106
# CloudWatch Basics: Billing Alarm & Alerting
# ==============================================================================
# NOTE: Billing metrics are only available in us-east-1. This validator
# explicitly targets us-east-1 for all checks regardless of your default
# AWS region configuration.
# ==============================================================================

ALARM_NAME="kata-106-BillingAlarm"
TOPIC_NAME="kata-106-BillingAlertTopic"
REGION="us-east-1"

PASS=0
FAIL=0

pass() { echo "✅ PASS — $1"; ((PASS++)); }
fail() { echo "❌ FAIL — $1"; ((FAIL++)); }

echo ""
echo "=================================================="
echo " CloudKata Validator — kata-106"
echo " CloudWatch Basics: Billing Alarm & Alerting"
echo "=================================================="
echo " Targeting region: $REGION (billing metrics are us-east-1 only)"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Resolve account ID for SNS topic ARN construction
# ------------------------------------------------------------------------------
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$ACCOUNT_ID" ]; then
  echo "❌ ERROR — Could not retrieve AWS account ID. Check your credentials."
  exit 1
fi

TOPIC_ARN="arn:aws:sns:${REGION}:${ACCOUNT_ID}:${TOPIC_NAME}"

# ------------------------------------------------------------------------------
# Check 1 — SNS topic exists in us-east-1 (hard gate)
# ------------------------------------------------------------------------------
echo "Checking SNS topic..."
SNS_RESULT=$(aws sns get-topic-attributes \
  --topic-arn "$TOPIC_ARN" \
  --region "$REGION" \
  --query 'Attributes.TopicArn' \
  --output text 2>/dev/null)

if [ -z "$SNS_RESULT" ] || [ "$SNS_RESULT" = "None" ]; then
  echo "❌ FAIL — SNS topic '$TOPIC_NAME' not found in $REGION. Cannot continue."
  echo ""
  echo "  Make sure the topic name is exactly: $TOPIC_NAME"
  echo "  Make sure the topic is in region: $REGION"
  echo ""
  echo "=================================================="
  echo " Results: 0/8 checks passed (0%)"
  echo "=================================================="
  exit 1
fi
pass "SNS topic '$TOPIC_NAME' exists in $REGION"

# ------------------------------------------------------------------------------
# Check 2 — CloudWatch alarm exists in us-east-1 (hard gate)
# ------------------------------------------------------------------------------
echo "Checking CloudWatch alarm..."
ALARM_JSON=$(aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --region "$REGION" \
  --query 'MetricAlarms[0]' \
  --output json 2>/dev/null)

ALARM_EXISTS=$(echo "$ALARM_JSON" | jq -r '.AlarmName // empty')

if [ -z "$ALARM_EXISTS" ] || [ "$ALARM_EXISTS" = "null" ]; then
  echo "❌ FAIL — Alarm '$ALARM_NAME' not found in $REGION. Cannot continue."
  echo ""
  echo "  Make sure the alarm name is exactly: $ALARM_NAME"
  echo "  Make sure the alarm is in region: $REGION"
  echo ""
  echo "=================================================="
  echo " Results: 1/8 checks passed (12%)"
  echo "=================================================="
  exit 1
fi
pass "Alarm '$ALARM_NAME' exists in $REGION"

# ------------------------------------------------------------------------------
# Check 3 — Alarm monitors the AWS/Billing namespace
# ------------------------------------------------------------------------------
echo "Checking alarm namespace..."
NAMESPACE=$(echo "$ALARM_JSON" | jq -r '.Namespace')

if [ "$NAMESPACE" = "AWS/Billing" ]; then
  pass "Alarm monitors the AWS/Billing namespace"
else
  fail "Alarm namespace is '$NAMESPACE' — must be AWS/Billing"
fi

# ------------------------------------------------------------------------------
# Check 4 — Alarm monitors the EstimatedCharges metric
# ------------------------------------------------------------------------------
echo "Checking alarm metric..."
METRIC_NAME=$(echo "$ALARM_JSON" | jq -r '.MetricName')

if [ "$METRIC_NAME" = "EstimatedCharges" ]; then
  pass "Alarm monitors the EstimatedCharges metric"
else
  fail "Alarm metric is '$METRIC_NAME' — must be EstimatedCharges"
fi

# ------------------------------------------------------------------------------
# Check 5 — Alarm dimension is Currency: USD (account-level total)
# ------------------------------------------------------------------------------
echo "Checking alarm dimensions..."
CURRENCY_DIM=$(echo "$ALARM_JSON" | \
  jq -r '.Dimensions[] | select(.Name == "Currency") | .Value' 2>/dev/null)

if [ "$CURRENCY_DIM" = "USD" ]; then
  pass "Alarm dimension is scoped to Currency: USD"
else
  # Check if there's a service-level dimension instead
  SERVICE_DIM=$(echo "$ALARM_JSON" | \
    jq -r '.Dimensions[] | select(.Name == "ServiceName") | .Value' 2>/dev/null)
  if [ -n "$SERVICE_DIM" ]; then
    fail "Alarm is scoped to service '$SERVICE_DIM' — must be account-level (Currency: USD only)"
  else
    fail "Alarm dimension Currency: USD not found — found: $(echo "$ALARM_JSON" | jq -r '.Dimensions')"
  fi
fi

# ------------------------------------------------------------------------------
# Check 6 — Alarm threshold is a positive value
# ------------------------------------------------------------------------------
echo "Checking alarm threshold..."
THRESHOLD=$(echo "$ALARM_JSON" | jq -r '.Threshold')

if [ -n "$THRESHOLD" ] && [ "$THRESHOLD" != "null" ]; then
  IS_POSITIVE=$(awk "BEGIN {print ($THRESHOLD > 0) ? 1 : 0}")
  if [ "$IS_POSITIVE" = "1" ]; then
    pass "Alarm threshold is a positive value (\$$THRESHOLD)"
  else
    fail "Alarm threshold is '$THRESHOLD' — must be a positive dollar amount"
  fi
else
  fail "Alarm threshold is not set"
fi

# ------------------------------------------------------------------------------
# Check 7 — Alarm action points to kata-106-BillingAlertTopic
# ------------------------------------------------------------------------------
echo "Checking alarm actions..."
ALARM_ACTION=$(echo "$ALARM_JSON" | \
  jq -r --arg arn "$TOPIC_ARN" \
  '.AlarmActions[] | select(. == $arn)' 2>/dev/null)

if [ -n "$ALARM_ACTION" ]; then
  pass "Alarm action points to '$TOPIC_NAME'"
else
  fail "Alarm action does not point to '$TOPIC_NAME' — check AlarmActions configuration"
fi

# ------------------------------------------------------------------------------
# Check 8 — Required tags on SNS topic
# ------------------------------------------------------------------------------
echo "Checking SNS topic tags..."
TAGS_JSON=$(aws sns list-tags-for-resource \
  --resource-arn "$TOPIC_ARN" \
  --region "$REGION" \
  --query 'Tags' \
  --output json 2>/dev/null)

PROJECT_TAG=$(echo "$TAGS_JSON" | \
  jq -r '.[] | select(.Key == "Project") | .Value' 2>/dev/null)
KATA_TAG=$(echo "$TAGS_JSON" | \
  jq -r '.[] | select(.Key == "Kata") | .Value' 2>/dev/null)

if [ "$PROJECT_TAG" = "CloudKata" ] && [ "$KATA_TAG" = "kata-106" ]; then
  pass "Required tags are present on SNS topic (Project: CloudKata, Kata: kata-106)"
else
  MISSING=""
  [ "$PROJECT_TAG" != "CloudKata" ] && MISSING="Project: CloudKata "
  [ "$KATA_TAG" != "kata-106" ] && MISSING="${MISSING}Kata: kata-106"
  fail "Missing or incorrect tags on SNS topic: $MISSING"
fi

# ------------------------------------------------------------------------------
# Results
# ------------------------------------------------------------------------------
PCT=$(( (PASS * 100) / 8 ))

echo ""
echo "=================================================="
echo " Results: $PASS/8 checks passed ($PCT%)"
echo "=================================================="

if [ "$PASS" -eq 8 ]; then
  echo " 🎉 Perfect score! All kata-106 requirements met."
elif [ "$PASS" -ge 5 ]; then
  echo " 🔧 Almost there — review the failed checks above."
else
  echo " 📖 Keep going — consult HINTS.md for guidance."
fi
echo ""