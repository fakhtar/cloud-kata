#!/bin/bash

# ==============================================================================
# CloudKata Validator — kata-103
# S3 Basics: Buckets, Versioning & Security
# ==============================================================================

PASS=0
FAIL=0

pass() { echo "✅ PASS — $1"; ((PASS++)); }
fail() { echo "❌ FAIL — $1"; ((FAIL++)); }

echo ""
echo "=================================================="
echo " CloudKata Validator — kata-103"
echo " S3 Basics: Buckets, Versioning & Security"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Resolve account ID and bucket name
# ------------------------------------------------------------------------------
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$ACCOUNT_ID" ]; then
  echo "❌ ERROR — Could not retrieve AWS account ID. Check your credentials."
  exit 1
fi

BUCKET_NAME="kata-103-bucket-${ACCOUNT_ID}"
echo "Validating bucket: $BUCKET_NAME"
echo ""

# ------------------------------------------------------------------------------
# Check 1 — Bucket exists (hard gate)
# ------------------------------------------------------------------------------
echo "Checking bucket existence..."
aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null
if [ $? -ne 0 ]; then
  echo "❌ FAIL — Bucket '$BUCKET_NAME' not found. Cannot continue."
  echo ""
  echo "  Make sure the bucket name matches: kata-103-bucket-${ACCOUNT_ID}"
  echo ""
  echo "=================================================="
  echo " Results: 0/8 checks passed (0%)"
  echo "=================================================="
  exit 1
fi
pass "Bucket '$BUCKET_NAME' exists"

# ------------------------------------------------------------------------------
# Check 2 — Versioning is enabled
# ------------------------------------------------------------------------------
echo "Checking versioning..."
VERSIONING=$(aws s3api get-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --query 'Status' \
  --output text 2>/dev/null)

if [ "$VERSIONING" = "Enabled" ]; then
  pass "Versioning is enabled"
else
  fail "Versioning is '${VERSIONING:-not configured}' — must be Enabled"
fi

# ------------------------------------------------------------------------------
# Checks 3-6 — Public access block (all four settings)
# ------------------------------------------------------------------------------
echo "Checking public access block configuration..."
PAB_JSON=$(aws s3api get-public-access-block \
  --bucket "$BUCKET_NAME" \
  --query 'PublicAccessBlockConfiguration' \
  --output json 2>/dev/null)

if [ -z "$PAB_JSON" ] || [ "$PAB_JSON" = "null" ]; then
  fail "BlockPublicAcls is not configured — public access block not found"
  fail "BlockPublicPolicy is not configured — public access block not found"
  fail "IgnorePublicAcls is not configured — public access block not found"
  fail "RestrictPublicBuckets is not configured — public access block not found"
else
  BLOCK_PUBLIC_ACLS=$(echo "$PAB_JSON" | jq -r '.BlockPublicAcls')
  BLOCK_PUBLIC_POLICY=$(echo "$PAB_JSON" | jq -r '.BlockPublicPolicy')
  IGNORE_PUBLIC_ACLS=$(echo "$PAB_JSON" | jq -r '.IgnorePublicAcls')
  RESTRICT_PUBLIC_BUCKETS=$(echo "$PAB_JSON" | jq -r '.RestrictPublicBuckets')

  [ "$BLOCK_PUBLIC_ACLS" = "true" ] && \
    pass "BlockPublicAcls is enabled" || \
    fail "BlockPublicAcls is not enabled"

  [ "$BLOCK_PUBLIC_POLICY" = "true" ] && \
    pass "BlockPublicPolicy is enabled" || \
    fail "BlockPublicPolicy is not enabled"

  [ "$IGNORE_PUBLIC_ACLS" = "true" ] && \
    pass "IgnorePublicAcls is enabled" || \
    fail "IgnorePublicAcls is not enabled"

  [ "$RESTRICT_PUBLIC_BUCKETS" = "true" ] && \
    pass "RestrictPublicBuckets is enabled" || \
    fail "RestrictPublicBuckets is not enabled"
fi

# ------------------------------------------------------------------------------
# Check 7 — Default server-side encryption is enabled
# ------------------------------------------------------------------------------
echo "Checking server-side encryption..."
ENCRYPTION=$(aws s3api get-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' \
  --output text 2>/dev/null)

if [ "$ENCRYPTION" = "AES256" ] || [ "$ENCRYPTION" = "aws:kms" ]; then
  pass "Default server-side encryption is enabled ($ENCRYPTION)"
else
  fail "Default server-side encryption is not configured — found: '${ENCRYPTION:-none}'"
fi

# ------------------------------------------------------------------------------
# Check 8 — Required tags are present
# ------------------------------------------------------------------------------
echo "Checking tags..."
TAGS_JSON=$(aws s3api get-bucket-tagging \
  --bucket "$BUCKET_NAME" \
  --output json 2>/dev/null)

PROJECT_TAG=$(echo "$TAGS_JSON" | \
  jq -r '.TagSet[] | select(.Key == "Project") | .Value' 2>/dev/null)
KATA_TAG=$(echo "$TAGS_JSON" | \
  jq -r '.TagSet[] | select(.Key == "Kata") | .Value' 2>/dev/null)

if [ "$PROJECT_TAG" = "CloudKata" ] && [ "$KATA_TAG" = "kata-103" ]; then
  pass "Required tags are present (Project: CloudKata, Kata: kata-103)"
else
  MISSING=""
  [ "$PROJECT_TAG" != "CloudKata" ] && MISSING="Project: CloudKata "
  [ "$KATA_TAG" != "kata-103" ] && MISSING="${MISSING}Kata: kata-103"
  fail "Missing or incorrect tags: $MISSING"
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
  echo " 🎉 Perfect score! All kata-103 requirements met."
elif [ "$PASS" -ge 5 ]; then
  echo " 🔧 Almost there — review the failed checks above."
else
  echo " 📖 Keep going — consult HINTS.md for guidance."
fi
echo ""