#!/bin/bash

# ==============================================================================
# CloudKata Validator — kata-200
# Amazon Connect Basics: Instance, Hours of Operation & Queue
# ==============================================================================

INSTANCE_ALIAS="kata-200-instance"
HOURS_NAME="kata-200-BasicHours"
QUEUE_NAME="kata-200-BasicQueue"
TOTAL_CHECKS=8

PASS=0
FAIL=0

pass() { echo "✅ PASS — $1"; ((PASS++)); }
fail() { echo "❌ FAIL — $1"; ((FAIL++)); }

echo ""
echo "=================================================="
echo " CloudKata Validator — kata-200"
echo " Amazon Connect Basics: Instance, Hours of Operation & Queue"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Check 1 — Connect instance exists (hard gate)
# ------------------------------------------------------------------------------
echo "Checking Connect instance..."
INSTANCE_JSON=$(aws connect list-instances \
  --output json 2>/dev/null | \
  jq --arg alias "$INSTANCE_ALIAS" \
  '.InstanceSummaryList[] | select(.InstanceAlias == $alias)' 2>/dev/null)

if [ -z "$INSTANCE_JSON" ]; then
  echo "❌ FAIL — Connect instance '$INSTANCE_ALIAS' not found. Cannot continue."
  echo ""
  echo "=================================================="
  echo " Results: 0/$TOTAL_CHECKS checks passed (0%)"
  echo "=================================================="
  exit 1
fi
pass "Connect instance '$INSTANCE_ALIAS' exists"

INSTANCE_ID=$(echo "$INSTANCE_JSON" | jq -r '.Id')
INSTANCE_STATUS=$(echo "$INSTANCE_JSON" | jq -r '.InstanceStatus')

# ------------------------------------------------------------------------------
# Check 2 — Instance status is ACTIVE
#
# Connect instances can take several minutes to become ACTIVE after creation.
# Poll up to 10 times (5 minutes) before failing.
# ------------------------------------------------------------------------------
echo "Checking instance status..."
if [ "$INSTANCE_STATUS" = "ACTIVE" ]; then
  pass "Instance status is ACTIVE"
else
  echo "  Instance status is '$INSTANCE_STATUS' — waiting for ACTIVE (up to 5 minutes)..."
  ATTEMPTS=0
  MAX_ATTEMPTS=10
  while [ "$INSTANCE_STATUS" != "ACTIVE" ] && [ "$ATTEMPTS" -lt "$MAX_ATTEMPTS" ]; do
    sleep 30
    ((ATTEMPTS++))
    INSTANCE_JSON=$(aws connect list-instances \
      --output json 2>/dev/null | \
      jq --arg alias "$INSTANCE_ALIAS" \
      '.InstanceSummaryList[] | select(.InstanceAlias == $alias)' 2>/dev/null)
    INSTANCE_STATUS=$(echo "$INSTANCE_JSON" | jq -r '.InstanceStatus')
    echo "  Attempt $ATTEMPTS/$MAX_ATTEMPTS — status: $INSTANCE_STATUS"
  done

  if [ "$INSTANCE_STATUS" = "ACTIVE" ]; then
    pass "Instance status is ACTIVE"
  else
    fail "Instance status is '$INSTANCE_STATUS' — expected ACTIVE"
    fail "Hours of operation '$HOURS_NAME' could not be checked — instance not ACTIVE"
    fail "Hours of operation schedule could not be checked — instance not ACTIVE"
    fail "Queue '$QUEUE_NAME' could not be checked — instance not ACTIVE"
    fail "Queue association could not be checked — instance not ACTIVE"
    fail "Required tags could not be checked on hours of operation — instance not ACTIVE"
    fail "Required tags could not be checked on queue — instance not ACTIVE"
    PCT=$(( (PASS * 100) / TOTAL_CHECKS ))
    echo ""
    echo "=================================================="
    echo " Results: $PASS/$TOTAL_CHECKS checks passed ($PCT%)"
    echo "=================================================="
    echo " 📖 Keep going — consult HINTS.md for guidance."
    echo ""
    exit 1
  fi
fi

# ------------------------------------------------------------------------------
# Check 3 — Hours of operation exists
# ------------------------------------------------------------------------------
echo "Checking hours of operation..."
HOURS_LIST=$(aws connect list-hours-of-operations \
  --instance-id "$INSTANCE_ID" \
  --output json 2>/dev/null)

HOURS_JSON=$(echo "$HOURS_LIST" | \
  jq --arg name "$HOURS_NAME" \
  '.HoursOfOperationSummaryList[] | select(.Name == $name)' 2>/dev/null)

if [ -z "$HOURS_JSON" ]; then
  fail "Hours of operation '$HOURS_NAME' not found in instance '$INSTANCE_ALIAS'"
  HOURS_ID=""
  HOURS_ARN=""
else
  pass "Hours of operation '$HOURS_NAME' exists"
  HOURS_ID=$(echo "$HOURS_JSON" | jq -r '.Id')
  HOURS_ARN=$(echo "$HOURS_JSON" | jq -r '.Arn')
fi

# ------------------------------------------------------------------------------
# Check 4 — Hours of operation covers Monday-Friday 09:00-17:00
# ------------------------------------------------------------------------------
echo "Checking hours of operation schedule..."
if [ -z "$HOURS_ID" ]; then
  fail "Hours of operation schedule could not be checked — hours of operation not found"
else
  HOURS_DETAIL=$(aws connect describe-hours-of-operation \
    --instance-id "$INSTANCE_ID" \
    --hours-of-operation-id "$HOURS_ID" \
    --output json 2>/dev/null)

  # Count Config entries that are weekdays (MON-FRI) with 09:00-17:00
  MATCHING_DAYS=$(echo "$HOURS_DETAIL" | jq '
    [.HoursOfOperation.Config[] |
      select(
        (.Day == "MONDAY" or .Day == "TUESDAY" or .Day == "WEDNESDAY" or
         .Day == "THURSDAY" or .Day == "FRIDAY") and
        .StartTime.Hours == 9 and .StartTime.Minutes == 0 and
        .EndTime.Hours == 17 and .EndTime.Minutes == 0
      )
    ] | length' 2>/dev/null)

  # All five weekdays must be present with correct times
  WEEKDAY_COUNT=$(echo "$HOURS_DETAIL" | jq '
    [.HoursOfOperation.Config[] |
      select(.Day == "MONDAY" or .Day == "TUESDAY" or .Day == "WEDNESDAY" or
             .Day == "THURSDAY" or .Day == "FRIDAY")
    ] | length' 2>/dev/null)

  if [ "$MATCHING_DAYS" -eq 5 ] && [ "$WEEKDAY_COUNT" -eq 5 ]; then
    pass "Hours of operation covers Monday to Friday, 09:00-17:00"
  else
    fail "Hours of operation schedule does not match Monday-Friday 09:00-17:00 — found $MATCHING_DAYS/5 matching weekday entries"
  fi
fi

# ------------------------------------------------------------------------------
# Check 5 — Queue exists
# ------------------------------------------------------------------------------
echo "Checking queue..."
QUEUE_LIST=$(aws connect list-queues \
  --instance-id "$INSTANCE_ID" \
  --queue-types STANDARD \
  --output json 2>/dev/null)

QUEUE_JSON=$(echo "$QUEUE_LIST" | \
  jq --arg name "$QUEUE_NAME" \
  '.QueueSummaryList[] | select(.Name == $name)' 2>/dev/null)

if [ -z "$QUEUE_JSON" ]; then
  fail "Queue '$QUEUE_NAME' not found in instance '$INSTANCE_ALIAS'"
  QUEUE_ID=""
  QUEUE_ARN=""
else
  pass "Queue '$QUEUE_NAME' exists"
  QUEUE_ID=$(echo "$QUEUE_JSON" | jq -r '.Id')
  QUEUE_ARN=$(echo "$QUEUE_JSON" | jq -r '.Arn')
fi

# ------------------------------------------------------------------------------
# Check 6 — Queue is associated with kata-200-BasicHours
# ------------------------------------------------------------------------------
echo "Checking queue association..."
if [ -z "$QUEUE_ID" ]; then
  fail "Queue association could not be checked — queue not found"
elif [ -z "$HOURS_ID" ]; then
  fail "Queue association could not be checked — hours of operation not found"
else
  QUEUE_DETAIL=$(aws connect describe-queue \
    --instance-id "$INSTANCE_ID" \
    --queue-id "$QUEUE_ID" \
    --output json 2>/dev/null)

  QUEUE_HOURS_ID=$(echo "$QUEUE_DETAIL" | jq -r '.Queue.HoursOfOperationId // empty' 2>/dev/null)

  if [ "$QUEUE_HOURS_ID" = "$HOURS_ID" ]; then
    pass "Queue is associated with '$HOURS_NAME'"
  else
    fail "Queue is not associated with '$HOURS_NAME' — check the hours of operation linked to the queue"
  fi
fi

# ------------------------------------------------------------------------------
# Check 7 — Required tags on hours of operation
# ------------------------------------------------------------------------------
echo "Checking hours of operation tags..."
if [ -z "$HOURS_ARN" ]; then
  fail "Required tags could not be checked on hours of operation — hours of operation not found"
else
  HOURS_TAGS=$(aws connect list-tags-for-resource \
    --resource-arn "$HOURS_ARN" \
    --output json 2>/dev/null)

  HOURS_PROJECT=$(echo "$HOURS_TAGS" | jq -r '.tags.Project // empty' 2>/dev/null)
  HOURS_KATA=$(echo "$HOURS_TAGS" | jq -r '.tags.Kata // empty' 2>/dev/null)

  if [ "$HOURS_PROJECT" = "CloudKata" ] && [ "$HOURS_KATA" = "kata-200" ]; then
    pass "Required tags are present on hours of operation"
  else
    MISSING=""
    [ "$HOURS_PROJECT" != "CloudKata" ] && MISSING="Project: CloudKata "
    [ "$HOURS_KATA" != "kata-200" ] && MISSING="${MISSING}Kata: kata-200"
    fail "Missing or incorrect tags on hours of operation: $MISSING"
  fi
fi

# ------------------------------------------------------------------------------
# Check 8 — Required tags on queue
# ------------------------------------------------------------------------------
echo "Checking queue tags..."
if [ -z "$QUEUE_ARN" ]; then
  fail "Required tags could not be checked on queue — queue not found"
else
  QUEUE_TAGS=$(aws connect list-tags-for-resource \
    --resource-arn "$QUEUE_ARN" \
    --output json 2>/dev/null)

  QUEUE_PROJECT=$(echo "$QUEUE_TAGS" | jq -r '.tags.Project // empty' 2>/dev/null)
  QUEUE_KATA=$(echo "$QUEUE_TAGS" | jq -r '.tags.Kata // empty' 2>/dev/null)

  if [ "$QUEUE_PROJECT" = "CloudKata" ] && [ "$QUEUE_KATA" = "kata-200" ]; then
    pass "Required tags are present on queue"
  else
    MISSING=""
    [ "$QUEUE_PROJECT" != "CloudKata" ] && MISSING="Project: CloudKata "
    [ "$QUEUE_KATA" != "kata-200" ] && MISSING="${MISSING}Kata: kata-200"
    fail "Missing or incorrect tags on queue: $MISSING"
  fi
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
  echo " 🎉 Perfect score! All kata-200 requirements met."
elif [ "$PASS" -ge 5 ]; then
  echo " 🔧 Almost there — review the failed checks above."
else
  echo " 📖 Keep going — consult HINTS.md for guidance."
fi
echo ""