#!/bin/bash
# =============================================================================
# CloudKata — kata-205 Validator
# kata:    kata-205
# title:   Lambda + SQS: Event Source Mapping & Error Handling
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

PROCESSING_QUEUE_NAME="kata-205-ProcessingQueue"
DLQ_NAME="kata-205-DeadLetterQueue"
FUNCTION_NAME="kata-205-ProcessorFunction"
SQS_MANAGED_POLICY_ARN="arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"

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
echo " CloudKata Validator — kata-205"
echo " Lambda + SQS: Event Source Mapping & Error Handling"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Check 1 — Processing queue exists
# ------------------------------------------------------------------------------
echo "Checking processing queue..."
PROCESSING_QUEUE_URL=$(aws sqs get-queue-url \
  --queue-name "$PROCESSING_QUEUE_NAME" \
  --query 'QueueUrl' \
  --output text 2>/dev/null || echo "NOT_FOUND")

PROCESSING_QUEUE_ARN=""
if [ "$PROCESSING_QUEUE_URL" != "NOT_FOUND" ] && [ "$PROCESSING_QUEUE_URL" != "None" ] && [ -n "$PROCESSING_QUEUE_URL" ]; then
  PROCESSING_QUEUE_ARN=$(aws sqs get-queue-attributes \
    --queue-url "$PROCESSING_QUEUE_URL" \
    --attribute-names QueueArn \
    --query 'Attributes.QueueArn' \
    --output text 2>/dev/null || echo "")
  pass "SQS queue '${PROCESSING_QUEUE_NAME}' exists"
else
  fail "SQS queue '${PROCESSING_QUEUE_NAME}'" "Queue not found — ensure a queue exists with the exact name '${PROCESSING_QUEUE_NAME}'"
fi

# ------------------------------------------------------------------------------
# Check 2 — Dead-letter queue exists
# ------------------------------------------------------------------------------
echo "Checking dead-letter queue..."
DLQ_URL=$(aws sqs get-queue-url \
  --queue-name "$DLQ_NAME" \
  --query 'QueueUrl' \
  --output text 2>/dev/null || echo "NOT_FOUND")

DLQ_ARN=""
if [ "$DLQ_URL" != "NOT_FOUND" ] && [ "$DLQ_URL" != "None" ] && [ -n "$DLQ_URL" ]; then
  DLQ_ARN=$(aws sqs get-queue-attributes \
    --queue-url "$DLQ_URL" \
    --attribute-names QueueArn \
    --query 'Attributes.QueueArn' \
    --output text 2>/dev/null || echo "")
  pass "Dead-letter queue '${DLQ_NAME}' exists"
else
  fail "Dead-letter queue '${DLQ_NAME}'" "Queue not found — ensure a queue exists with the exact name '${DLQ_NAME}'"
fi

# ------------------------------------------------------------------------------
# Check 3 — Processing queue routes failed messages to the DLQ
# ------------------------------------------------------------------------------
echo "Checking redrive policy on processing queue..."
if [ -n "$PROCESSING_QUEUE_ARN" ]; then
  REDRIVE_POLICY=$(aws sqs get-queue-attributes \
    --queue-url "$PROCESSING_QUEUE_URL" \
    --attribute-names RedrivePolicy \
    --query 'Attributes.RedrivePolicy' \
    --output text 2>/dev/null || echo "None")

  if [ "$REDRIVE_POLICY" = "None" ] || [ -z "$REDRIVE_POLICY" ]; then
    fail "Redrive policy" "Processing queue has no redrive policy — configure it to send failed messages to '${DLQ_NAME}'"
  else
    DLT_ARN=$(echo "$REDRIVE_POLICY" | sed -nE 's/.*"deadLetterTargetArn"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p')
    MAX_RECEIVE=$(echo "$REDRIVE_POLICY" | sed -nE 's/.*"maxReceiveCount"[[:space:]]*:[[:space:]]*"?([0-9]+)"?.*/\1/p')

    TARGET_OK="no"
    if [ -n "$DLQ_ARN" ] && [ "$DLT_ARN" = "$DLQ_ARN" ]; then
      TARGET_OK="yes"
    elif echo "$DLT_ARN" | grep -q "${DLQ_NAME}$"; then
      TARGET_OK="yes"
    fi

    if [ "$TARGET_OK" = "yes" ] && [ -n "$MAX_RECEIVE" ] && [ "$MAX_RECEIVE" -ge 1 ] 2>/dev/null; then
      pass "Processing queue routes failed messages to the dead-letter queue (maxReceiveCount: ${MAX_RECEIVE})"
    elif [ "$TARGET_OK" != "yes" ]; then
      fail "Redrive policy" "Redrive policy target '${DLT_ARN}' does not point to '${DLQ_NAME}'"
    else
      fail "Redrive policy" "Redrive policy is missing a valid maxReceiveCount"
    fi
  fi
else
  fail "Redrive policy" "Cannot check redrive policy — processing queue '${PROCESSING_QUEUE_NAME}' was not found"
fi

# ------------------------------------------------------------------------------
# Check 4 — Lambda function exists
# ------------------------------------------------------------------------------
echo "Checking Lambda function..."
FUNCTION_ROLE_ARN=$(aws lambda get-function-configuration \
  --function-name "$FUNCTION_NAME" \
  --query 'Role' \
  --output text 2>/dev/null || echo "NOT_FOUND")

FUNCTION_EXISTS="no"
if [ "$FUNCTION_ROLE_ARN" != "NOT_FOUND" ] && [ "$FUNCTION_ROLE_ARN" != "None" ] && [ -n "$FUNCTION_ROLE_ARN" ]; then
  FUNCTION_EXISTS="yes"
  pass "Lambda function '${FUNCTION_NAME}' exists"
else
  fail "Lambda function '${FUNCTION_NAME}'" "Function not found — ensure a function exists with the exact name '${FUNCTION_NAME}'"
fi

# ------------------------------------------------------------------------------
# Check 5 — Execution role permits consuming from the queue
# (a) inspect the role's policies for SQS consume permission;
#     fall back to an active event source mapping as proof.
# ------------------------------------------------------------------------------
echo "Checking function execution-role permissions..."
if [ "$FUNCTION_EXISTS" = "yes" ]; then
  ROLE_NAME="${FUNCTION_ROLE_ARN##*/}"
  PERMISSION_FOUND="no"

  # (a1) Known AWS managed policy attached?
  ATTACHED_ARNS=$(aws iam list-attached-role-policies \
    --role-name "$ROLE_NAME" \
    --query 'AttachedPolicies[].PolicyArn' \
    --output text 2>/dev/null || echo "")

  if echo "$ATTACHED_ARNS" | grep -q "$SQS_MANAGED_POLICY_ARN"; then
    PERMISSION_FOUND="yes"
  fi

  # (a2) Otherwise scan all policy documents (customer-managed + inline)
  #      for an SQS receive grant.
  if [ "$PERMISSION_FOUND" = "no" ] && [ -n "$ATTACHED_ARNS" ]; then
    for ARN in $ATTACHED_ARNS; do
      VERSION_ID=$(aws iam get-policy --policy-arn "$ARN" \
        --query 'Policy.DefaultVersionId' --output text 2>/dev/null || echo "")
      if [ -n "$VERSION_ID" ] && [ "$VERSION_ID" != "None" ]; then
        DOC=$(aws iam get-policy-version --policy-arn "$ARN" --version-id "$VERSION_ID" \
          --output json 2>/dev/null || echo "")
        if echo "$DOC" | grep -Eiq 'receivemessage|sqs:\*|sqs%3a\*'; then
          PERMISSION_FOUND="yes"
          break
        fi
      fi
    done
  fi

  if [ "$PERMISSION_FOUND" = "no" ]; then
    INLINE_NAMES=$(aws iam list-role-policies \
      --role-name "$ROLE_NAME" \
      --query 'PolicyNames[]' \
      --output text 2>/dev/null || echo "")
    for PNAME in $INLINE_NAMES; do
      DOC=$(aws iam get-role-policy --role-name "$ROLE_NAME" --policy-name "$PNAME" \
        --output json 2>/dev/null || echo "")
      if echo "$DOC" | grep -Eiq 'receivemessage|sqs:\*|sqs%3a\*'; then
        PERMISSION_FOUND="yes"
        break
      fi
    done
  fi

  if [ "$PERMISSION_FOUND" = "yes" ]; then
    pass "Function's execution role permits consuming from the queue"
  else
    # Fallback: an active event source mapping implies working permissions.
    FALLBACK_STATE="NONE"
    if [ -n "$PROCESSING_QUEUE_ARN" ]; then
      FALLBACK_STATE=$(aws lambda list-event-source-mappings \
        --function-name "$FUNCTION_NAME" \
        --event-source-arn "$PROCESSING_QUEUE_ARN" \
        --query 'EventSourceMappings[0].State' \
        --output text 2>/dev/null || echo "NONE")
    fi
    if [ "$FALLBACK_STATE" = "Enabled" ]; then
      pass "Function's execution role permits consuming from the queue (inferred from active event source mapping)"
    else
      fail "Execution-role permissions" "No SQS receive permission found on the execution role — attach AWSLambdaSQSQueueExecutionRole or grant sqs:ReceiveMessage/DeleteMessage/GetQueueAttributes on '${PROCESSING_QUEUE_NAME}'"
    fi
  fi
else
  fail "Execution-role permissions" "Cannot check permissions — function '${FUNCTION_NAME}' was not found"
fi

# ------------------------------------------------------------------------------
# Check 6 — Event source mapping connects the queue to the function and is enabled
# ------------------------------------------------------------------------------
echo "Checking event source mapping..."
if [ "$FUNCTION_EXISTS" = "yes" ] && [ -n "$PROCESSING_QUEUE_ARN" ]; then
  ESM_TEXT=$(aws lambda list-event-source-mappings \
    --function-name "$FUNCTION_NAME" \
    --event-source-arn "$PROCESSING_QUEUE_ARN" \
    --query 'EventSourceMappings[0].[State,BatchSize]' \
    --output text 2>/dev/null || echo "None")
  read -r ESM_STATE ESM_BATCH <<< "$ESM_TEXT"

  if [ -z "$ESM_STATE" ] || [ "$ESM_STATE" = "None" ]; then
    fail "Event source mapping" "No event source mapping found linking '${PROCESSING_QUEUE_NAME}' to '${FUNCTION_NAME}'"
  elif [ "$ESM_STATE" = "Enabled" ]; then
    pass "Event source mapping connects the queue to the function and is enabled (batch size: ${ESM_BATCH})"
  else
    fail "Event source mapping" "Mapping exists but its state is '${ESM_STATE}', not 'Enabled' — enable the mapping"
  fi
else
  fail "Event source mapping" "Cannot check mapping — function and/or processing queue was not found"
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
  echo " 🎉 Perfect score! All kata-205 requirements met."
  echo ""
fi

if [ "$FAIL" -gt 0 ]; then
  echo " Review the failed checks above, fix your infrastructure,"
  echo " and re-run this validator."
  echo ""
  exit 1
fi