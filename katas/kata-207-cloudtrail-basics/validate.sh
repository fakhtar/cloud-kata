#!/bin/bash

# ==============================================================================
# CloudKata Validator -- kata-207
# CloudTrail Basics: Trails, Events & Audit Logging
# ==============================================================================

TRAIL_NAME="kata-207-AuditTrail"
BUCKET_PREFIX="kata-207-trail-logs-"

PASS=0
FAIL=0
TOTAL=6

pass() { echo "✅ PASS -- $1"; ((PASS++)); }
fail() { echo "❌ FAIL -- $1: $2"; ((FAIL++)); }

echo ""
echo "=================================================="
echo " CloudKata Validator -- kata-207"
echo " CloudTrail Basics: Trails, Events & Audit Logging"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Resolve account ID (used to identify the expected bucket name)
# ------------------------------------------------------------------------------
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
EXPECTED_BUCKET="${BUCKET_PREFIX}${ACCOUNT_ID}"

# ------------------------------------------------------------------------------
# Check 1 -- S3 bucket for log delivery exists
# ------------------------------------------------------------------------------
echo "Checking S3 bucket..."
BUCKET_NAME=""
if aws s3api head-bucket --bucket "$EXPECTED_BUCKET" > /dev/null 2>&1; then
  pass "S3 bucket for log delivery exists"
  BUCKET_NAME="$EXPECTED_BUCKET"
else
  # Fallback: search for any bucket matching the prefix in case account ID is
  # different (e.g. when running across assumed roles)
  BUCKET_NAME=$(aws s3api list-buckets \
    --query "Buckets[?starts_with(Name, '${BUCKET_PREFIX}')].Name" \
    --output text 2>/dev/null | head -1)

  if [ -n "$BUCKET_NAME" ] && [ "$BUCKET_NAME" != "None" ]; then
    pass "S3 bucket for log delivery exists"
  else
    fail "S3 bucket for log delivery not found" \
      "Create an S3 bucket named '${EXPECTED_BUCKET}' in this region"
    BUCKET_NAME=""
  fi
fi

# ------------------------------------------------------------------------------
# Check 2 -- S3 bucket policy grants CloudTrail delivery permission
# ------------------------------------------------------------------------------
echo "Checking S3 bucket policy..."
if [ -n "$BUCKET_NAME" ]; then
  BUCKET_POLICY=$(aws s3api get-bucket-policy \
    --bucket "$BUCKET_NAME" \
    --query 'Policy' \
    --output text 2>/dev/null)

  CT_ALLOWED=$(echo "$BUCKET_POLICY" | jq -r '
    .Statement[]
    | select(
        (.Effect == "Allow") and
        (
          (.Principal.Service == "cloudtrail.amazonaws.com") or
          ((.Principal.Service // []) | arrays | any(. == "cloudtrail.amazonaws.com"))
        ) and
        (
          ((.Action == "s3:PutObject") or (.Action == "s3:GetBucketAcl")) or
          ((.Action // []) | arrays | any(. == "s3:PutObject" or . == "s3:GetBucketAcl"))
        )
      )
    | .Effect' 2>/dev/null | head -1)

  if [ "$CT_ALLOWED" = "Allow" ]; then
    pass "S3 bucket policy grants CloudTrail delivery permission"
  else
    fail "S3 bucket policy does not grant CloudTrail delivery permission" \
      "Add a bucket policy allowing cloudtrail.amazonaws.com to s3:GetBucketAcl and s3:PutObject"
  fi
else
  fail "Cannot check S3 bucket policy" \
    "S3 bucket '${EXPECTED_BUCKET}' was not found -- create it first"
fi

# ------------------------------------------------------------------------------
# Check 3 -- CloudTrail trail exists
# ------------------------------------------------------------------------------
echo "Checking CloudTrail trail..."
TRAIL_JSON=$(aws cloudtrail describe-trails \
  --trail-name-list "$TRAIL_NAME" \
  --output json 2>/dev/null)

TRAIL_FOUND=$(echo "$TRAIL_JSON" | jq -r '.trailList[0].Name // empty' 2>/dev/null)

if [ "$TRAIL_FOUND" = "$TRAIL_NAME" ]; then
  pass "CloudTrail trail '$TRAIL_NAME' exists"
  TRAIL_ARN=$(echo "$TRAIL_JSON" | jq -r '.trailList[0].TrailARN // empty' 2>/dev/null)
  TRAIL_BUCKET=$(echo "$TRAIL_JSON" | jq -r '.trailList[0].S3BucketName // empty' 2>/dev/null)
else
  fail "CloudTrail trail '$TRAIL_NAME' not found" \
    "Create a CloudTrail trail named exactly '$TRAIL_NAME' in this region"
  TRAIL_ARN=""
  TRAIL_BUCKET=""
fi

# ------------------------------------------------------------------------------
# Check 4 -- Trail is actively logging
# ------------------------------------------------------------------------------
echo "Checking trail logging status..."
if [ -n "$TRAIL_ARN" ]; then
  IS_LOGGING=$(aws cloudtrail get-trail-status \
    --name "$TRAIL_ARN" \
    --query 'IsLogging' \
    --output text 2>/dev/null)

  if [ "$IS_LOGGING" = "True" ] || [ "$IS_LOGGING" = "true" ]; then
    pass "Trail is actively logging"
  else
    fail "Trail is not actively logging" \
      "Start logging on '$TRAIL_NAME' -- go to CloudTrail and enable logging for the trail"
  fi
else
  fail "Cannot check trail logging status" \
    "Trail '$TRAIL_NAME' was not found -- create it first"
fi

# ------------------------------------------------------------------------------
# Check 5 -- Trail delivers logs to the correct S3 bucket
# ------------------------------------------------------------------------------
echo "Checking trail S3 bucket configuration..."
if [ -n "$TRAIL_BUCKET" ] && [ -n "$BUCKET_NAME" ]; then
  if [ "$TRAIL_BUCKET" = "$BUCKET_NAME" ]; then
    pass "Trail delivers logs to the correct S3 bucket"
  else
    fail "Trail is delivering to bucket '$TRAIL_BUCKET'" \
      "Expected bucket '$BUCKET_NAME' -- update the trail to deliver to the correct bucket"
  fi
elif [ -n "$TRAIL_ARN" ]; then
  fail "Cannot verify trail S3 bucket" \
    "S3 bucket '$EXPECTED_BUCKET' was not found -- create it first"
else
  fail "Cannot check trail S3 bucket" \
    "Trail '$TRAIL_NAME' was not found -- create it first"
fi

# ------------------------------------------------------------------------------
# Check 6 -- Trail logs management events (Read and Write)
# ------------------------------------------------------------------------------
echo "Checking event selectors..."
if [ -n "$TRAIL_ARN" ]; then
  SELECTORS_JSON=$(aws cloudtrail get-event-selectors \
    --trail-name "$TRAIL_ARN" \
    --output json 2>/dev/null)

  # Check basic event selectors first
  MGMT_ALL=$(echo "$SELECTORS_JSON" | jq -r '
    .EventSelectors[]?
    | select(
        (.IncludeManagementEvents == true) and
        (.ReadWriteType == "All")
      )
    | "found"' 2>/dev/null | head -1)

  if [ "$MGMT_ALL" = "found" ]; then
    pass "Trail logs management events (Read and Write)"
  else
    # Check advanced event selectors -- management events are logged by default
    # when advanced selectors are used, indicated by a Management category selector
    ADV_MGMT=$(echo "$SELECTORS_JSON" | jq -r '
      .AdvancedEventSelectors[]?
      | select(
          .FieldSelectors[]?
          | select(.Field == "eventCategory" and (.Equals[]? == "Management"))
        )
      | "found"' 2>/dev/null | head -1)

    if [ "$ADV_MGMT" = "found" ]; then
      pass "Trail logs management events (Read and Write)"
    else
      fail "Trail does not log management events with ReadWriteType All" \
        "Configure the trail event selectors to include management events with Read and Write"
    fi
  fi
else
  fail "Cannot check event selectors" \
    "Trail '$TRAIL_NAME' was not found -- create it first"
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
  echo " 🎉 Perfect score! All kata-207 requirements met."
elif [ "$PASS" -ge 4 ]; then
  echo " 🔧 Almost there -- review the failed checks above."
else
  echo " 📖 Keep going -- consult HINTS.md for guidance."
fi
echo ""