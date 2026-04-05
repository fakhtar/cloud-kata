#!/bin/bash
# =============================================================================
# CloudKata — kata-107 Validator
# kata:    kata-107
# title:   SQS Basics: Queues, Visibility & Dead-Letter Queues
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

PRIMARY_QUEUE_NAME="kata-107-PrimaryQueue"
SECONDARY_QUEUE_NAME="kata-107-SecondaryQueue"
DEFAULT_VISIBILITY_TIMEOUT="30"

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
echo " CloudKata Validator — kata-107"
echo " SQS Basics: Queues, Visibility & Dead-Letter Queues"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Check 1 — Primary queue exists
# ------------------------------------------------------------------------------
echo "Checking queue existence: ${PRIMARY_QUEUE_NAME}..."
PRIMARY_URL=$(aws sqs get-queue-url \
  --queue-name "$PRIMARY_QUEUE_NAME" \
  --query 'QueueUrl' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$PRIMARY_URL" != "NOT_FOUND" ] && [ -n "$PRIMARY_URL" ]; then
  pass "Queue '${PRIMARY_QUEUE_NAME}' exists"
else
  fail "Queue '${PRIMARY_QUEUE_NAME}'" "Queue not found — ensure a standard SQS queue named exactly '${PRIMARY_QUEUE_NAME}' exists"
  PRIMARY_URL=""
fi

# ------------------------------------------------------------------------------
# Check 2 — Secondary queue exists
# ------------------------------------------------------------------------------
echo "Checking queue existence: ${SECONDARY_QUEUE_NAME}..."
SECONDARY_URL=$(aws sqs get-queue-url \
  --queue-name "$SECONDARY_QUEUE_NAME" \
  --query 'QueueUrl' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$SECONDARY_URL" != "NOT_FOUND" ] && [ -n "$SECONDARY_URL" ]; then
  pass "Queue '${SECONDARY_QUEUE_NAME}' exists"
else
  fail "Queue '${SECONDARY_QUEUE_NAME}'" "Queue not found — ensure a standard SQS queue named exactly '${SECONDARY_QUEUE_NAME}' exists"
  SECONDARY_URL=""
fi

# ------------------------------------------------------------------------------
# Fetch primary queue attributes (needed for checks 3–5)
# ------------------------------------------------------------------------------
if [ -n "$PRIMARY_URL" ]; then
  PRIMARY_ATTRS=$(aws sqs get-queue-attributes \
    --queue-url "$PRIMARY_URL" \
    --attribute-names All \
    --output json 2>/dev/null || echo "{}")
else
  PRIMARY_ATTRS="{}"
fi

# ------------------------------------------------------------------------------
# Check 3 — Primary queue visibility timeout is not the default (30s)
# ------------------------------------------------------------------------------
echo "Checking visibility timeout on ${PRIMARY_QUEUE_NAME}..."
if [ -n "$PRIMARY_URL" ]; then
  VIS_TIMEOUT=$(echo "$PRIMARY_ATTRS" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('Attributes',{}).get('VisibilityTimeout','NOT_FOUND'))" 2>/dev/null || echo "NOT_FOUND")

  if [ "$VIS_TIMEOUT" = "NOT_FOUND" ] || [ -z "$VIS_TIMEOUT" ]; then
    fail "PrimaryQueue visibility timeout" "Could not read VisibilityTimeout — check your IAM permissions"
  elif [ "$VIS_TIMEOUT" = "$DEFAULT_VISIBILITY_TIMEOUT" ]; then
    fail "PrimaryQueue visibility timeout" "VisibilityTimeout is set to the default (${DEFAULT_VISIBILITY_TIMEOUT}s) — configure a non-default value on '${PRIMARY_QUEUE_NAME}'"
  else
    pass "PrimaryQueue visibility timeout is set to a non-default value (${VIS_TIMEOUT}s)"
  fi
else
  fail "PrimaryQueue visibility timeout" "Cannot check — queue '${PRIMARY_QUEUE_NAME}' was not found"
fi

# ------------------------------------------------------------------------------
# Check 4 — Primary queue has a redrive policy configured
# ------------------------------------------------------------------------------
echo "Checking redrive policy on ${PRIMARY_QUEUE_NAME}..."
REDRIVE_RAW=""
if [ -n "$PRIMARY_URL" ]; then
  REDRIVE_RAW=$(echo "$PRIMARY_ATTRS" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('Attributes',{}).get('RedrivePolicy','NOT_FOUND'))" 2>/dev/null || echo "NOT_FOUND")

  if [ "$REDRIVE_RAW" = "NOT_FOUND" ] || [ -z "$REDRIVE_RAW" ]; then
    fail "PrimaryQueue redrive policy" "No redrive policy found on '${PRIMARY_QUEUE_NAME}' — configure message routing to '${SECONDARY_QUEUE_NAME}' for failed messages"
    REDRIVE_RAW=""
  else
    pass "PrimaryQueue has a redrive policy configured"
  fi
else
  fail "PrimaryQueue redrive policy" "Cannot check — queue '${PRIMARY_QUEUE_NAME}' was not found"
fi

# ------------------------------------------------------------------------------
# Check 5 — Redrive policy points to the secondary queue
# ------------------------------------------------------------------------------
echo "Checking redrive policy target..."
if [ -n "$REDRIVE_RAW" ] && [ -n "$SECONDARY_URL" ]; then
  SECONDARY_ARN=$(aws sqs get-queue-attributes \
    --queue-url "$SECONDARY_URL" \
    --attribute-names QueueArn \
    --query 'Attributes.QueueArn' \
    --output text 2>/dev/null || echo "NOT_FOUND")

  POLICY_TARGET_ARN=$(echo "$REDRIVE_RAW" | \
    python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('deadLetterTargetArn','NOT_FOUND'))" 2>/dev/null || echo "NOT_FOUND")

  if [ "$POLICY_TARGET_ARN" = "$SECONDARY_ARN" ]; then
    pass "PrimaryQueue redrive policy routes to '${SECONDARY_QUEUE_NAME}'"
  else
    fail "PrimaryQueue redrive policy target" "Redrive policy does not point to '${SECONDARY_QUEUE_NAME}' — ensure failed messages are routed to the correct queue"
  fi
elif [ -z "$REDRIVE_RAW" ]; then
  fail "PrimaryQueue redrive policy target" "Cannot check — no redrive policy was found on '${PRIMARY_QUEUE_NAME}'"
else
  fail "PrimaryQueue redrive policy target" "Cannot check — queue '${SECONDARY_QUEUE_NAME}' was not found"
fi

# ------------------------------------------------------------------------------
# Check 6 — maxReceiveCount is explicitly set
# ------------------------------------------------------------------------------
echo "Checking maxReceiveCount on ${PRIMARY_QUEUE_NAME}..."
if [ -n "$REDRIVE_RAW" ]; then
  MAX_RECEIVE=$(echo "$REDRIVE_RAW" | \
    python3 -c "import sys,json; d=json.loads(sys.stdin.read()); v=d.get('maxReceiveCount','NOT_FOUND'); print(str(v))" 2>/dev/null || echo "NOT_FOUND")

  if [ "$MAX_RECEIVE" = "NOT_FOUND" ] || [ -z "$MAX_RECEIVE" ]; then
    fail "PrimaryQueue maxReceiveCount" "maxReceiveCount is not set — configure the maximum number of receive attempts before messages are routed to '${SECONDARY_QUEUE_NAME}'"
  else
    pass "PrimaryQueue maxReceiveCount is explicitly configured (value: ${MAX_RECEIVE})"
  fi
else
  fail "PrimaryQueue maxReceiveCount" "Cannot check — no redrive policy was found on '${PRIMARY_QUEUE_NAME}'"
fi

# ------------------------------------------------------------------------------
# Check 7 — Both queues tagged Project=CloudKata and Kata=kata-107
# ------------------------------------------------------------------------------
echo "Checking tags on both queues..."
TAG_FAIL=0

for QUEUE_NAME in "$PRIMARY_QUEUE_NAME" "$SECONDARY_QUEUE_NAME"; do
  if [ "$QUEUE_NAME" = "$PRIMARY_QUEUE_NAME" ]; then
    QUEUE_URL="$PRIMARY_URL"
  else
    QUEUE_URL="$SECONDARY_URL"
  fi

  if [ -n "$QUEUE_URL" ]; then
    TAGS=$(aws sqs list-queue-tags \
      --queue-url "$QUEUE_URL" \
      --output json 2>/dev/null || echo "{}")

    PROJECT_TAG=$(echo "$TAGS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('Tags',{}).get('Project','NOT_FOUND'))" 2>/dev/null || echo "NOT_FOUND")
    KATA_TAG=$(echo "$TAGS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('Tags',{}).get('Kata','NOT_FOUND'))" 2>/dev/null || echo "NOT_FOUND")

    if [ "$PROJECT_TAG" != "CloudKata" ]; then
      echo "   ✘ '${QUEUE_NAME}' — missing or incorrect tag Project (expected 'CloudKata', got '${PROJECT_TAG}')"
      TAG_FAIL=$((TAG_FAIL + 1))
    fi

    if [ "$KATA_TAG" != "kata-107" ]; then
      echo "   ✘ '${QUEUE_NAME}' — missing or incorrect tag Kata (expected 'kata-107', got '${KATA_TAG}')"
      TAG_FAIL=$((TAG_FAIL + 1))
    fi
  else
    echo "   ✘ '${QUEUE_NAME}' — cannot check tags, queue not found"
    TAG_FAIL=$((TAG_FAIL + 1))
  fi
done

if [ "$TAG_FAIL" -eq 0 ]; then
  pass "Both queues are tagged correctly (Project=CloudKata, Kata=kata-107)"
else
  fail "Queue tags" "${TAG_FAIL} tag issue(s) found — ensure both queues carry the tags Project=CloudKata and Kata=kata-107"
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
  echo " 🎉 Perfect score! All kata-107 requirements met."
  echo ""
fi

if [ "$FAIL" -gt 0 ]; then
  echo " Review the failed checks above, fix your infrastructure,"
  echo " and re-run this validator."
  echo ""
  exit 1
fi