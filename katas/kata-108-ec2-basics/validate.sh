#!/bin/bash

# ==============================================================================
# CloudKata Validator — kata-108
# EC2 Basics: Instances, Security Groups & Key Pairs
# ==============================================================================

KEYPAIR_NAME="kata-108-KeyPair"
SG_NAME="kata-108-SecurityGroup"
INSTANCE_NAME="kata-108-Instance"
INSTANCE_TYPE="t3.micro"

PASS=0
FAIL=0
TOTAL=9

pass() { echo "✅ PASS — $1"; ((PASS++)); }
fail() { echo "❌ FAIL — $1: $2"; ((FAIL++)); }

echo ""
echo "=================================================="
echo " CloudKata Validator — kata-108"
echo " EC2 Basics: Instances, Security Groups & Key Pairs"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Check 1 — Key pair exists
# ------------------------------------------------------------------------------
echo "Checking key pair..."
KP_RESULT=$(aws ec2 describe-key-pairs \
  --key-names "$KEYPAIR_NAME" \
  --query 'KeyPairs[0].KeyName' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$KP_RESULT" = "$KEYPAIR_NAME" ]; then
  pass "Key pair '$KEYPAIR_NAME' exists"
else
  fail "Key pair '$KEYPAIR_NAME' not found" \
    "Create a key pair named exactly '$KEYPAIR_NAME' in this region"
fi

# ------------------------------------------------------------------------------
# Check 2 — Security group exists
# ------------------------------------------------------------------------------
echo "Checking security group..."
SG_JSON=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=${SG_NAME}" \
  --query 'SecurityGroups[0]' \
  --output json 2>/dev/null)

SG_ID=$(echo "$SG_JSON" | jq -r '.GroupId // empty')

if [ -z "$SG_ID" ] || [ "$SG_ID" = "null" ]; then
  fail "Security group '$SG_NAME' not found" \
    "Create a security group named exactly '$SG_NAME'"
  SG_ID=""
else
  pass "Security group '$SG_NAME' exists"
fi

# ------------------------------------------------------------------------------
# Check 3 — Security group has SSH inbound rule on port 22
# ------------------------------------------------------------------------------
echo "Checking SSH inbound rule..."
if [ -n "$SG_ID" ]; then
  SSH_RULE=$(echo "$SG_JSON" | jq -r '
    .IpPermissions[]
    | select(
        .IpProtocol == "tcp" and
        (has("FromPort") and has("ToPort")) and
        .FromPort <= 22 and
        .ToPort >= 22
      )
    | .IpProtocol' 2>/dev/null | head -1)

  if [ -n "$SSH_RULE" ]; then
    pass "Security group has SSH inbound rule on port 22"
  else
    fail "No SSH inbound rule found on port 22" \
      "Add a TCP inbound rule for port 22 to '$SG_NAME'"
  fi
else
  fail "Cannot check SSH rule" \
    "Security group '$SG_NAME' was not found"
fi

# ------------------------------------------------------------------------------
# Check 4 — Security group has unrestricted outbound rule
# ------------------------------------------------------------------------------
echo "Checking outbound rules..."
if [ -n "$SG_ID" ]; then
  OUTBOUND_RULE=$(echo "$SG_JSON" | jq -r '
    .IpPermissionsEgress[]
    | select(
        .IpProtocol == "-1" and
        ((.IpRanges // []) | any(.; .CidrIp == "0.0.0.0/0"))
      )
    | .IpProtocol' 2>/dev/null | head -1)

  if [ -n "$OUTBOUND_RULE" ]; then
    pass "Security group has unrestricted outbound rule"
  else
    fail "No unrestricted outbound rule found" \
      "Add an outbound rule allowing all traffic to 0.0.0.0/0 in '$SG_NAME'"
  fi
else
  fail "Cannot check outbound rule" \
    "Security group '$SG_NAME' was not found"
fi

# ------------------------------------------------------------------------------
# Check 5 — Instance exists (hard gate for checks 6-9)
# ------------------------------------------------------------------------------
echo "Checking instance..."
INSTANCE_JSON=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${INSTANCE_NAME}" \
            "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[0].Instances[0]' \
  --output json 2>/dev/null)

INSTANCE_ID=$(echo "$INSTANCE_JSON" | jq -r '.InstanceId // empty')
INSTANCE_STATE=$(echo "$INSTANCE_JSON" | jq -r '.State.Name // empty')

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "null" ]; then
  fail "Instance '$INSTANCE_NAME' not found" \
    "Launch an EC2 instance with the Name tag '$INSTANCE_NAME'. Terminated instances are excluded."
  echo ""
  echo "=================================================="
  PCT=$(( (PASS * 100) / TOTAL ))
  echo " Results: $PASS/$TOTAL checks passed ($PCT%)"
  echo "=================================================="
  echo " 📖 Keep going — consult HINTS.md for guidance."
  echo ""
  exit 1
fi

pass "Instance '$INSTANCE_NAME' exists"

# ------------------------------------------------------------------------------
# Check 6 — Instance type is t3.micro
# ------------------------------------------------------------------------------
echo "Checking instance type..."
ACTUAL_TYPE=$(echo "$INSTANCE_JSON" | jq -r '.InstanceType // empty')

if [ "$ACTUAL_TYPE" = "$INSTANCE_TYPE" ]; then
  pass "Instance type is $INSTANCE_TYPE"
else
  fail "Instance type is '$ACTUAL_TYPE'" \
    "Expected '$INSTANCE_TYPE' — re-launch the instance with the correct type"
fi

# ------------------------------------------------------------------------------
# Check 7 — Instance state is running
# ------------------------------------------------------------------------------
echo "Checking instance state..."
if [ "$INSTANCE_STATE" = "running" ]; then
  pass "Instance state is running"
else
  fail "Instance state is '$INSTANCE_STATE'" \
    "The instance must be in a 'running' state — start it if it is stopped"
fi

# ------------------------------------------------------------------------------
# Check 8 — Instance is using the correct key pair
# ------------------------------------------------------------------------------
echo "Checking key pair association..."
INSTANCE_KP=$(echo "$INSTANCE_JSON" | jq -r '.KeyName // empty')

if [ "$INSTANCE_KP" = "$KEYPAIR_NAME" ]; then
  pass "Instance is using key pair '$KEYPAIR_NAME'"
elif [ -z "$INSTANCE_KP" ] || [ "$INSTANCE_KP" = "null" ]; then
  fail "Instance has no key pair associated" \
    "A key pair cannot be changed after launch — terminate and re-launch with '$KEYPAIR_NAME'"
else
  fail "Instance is using key pair '$INSTANCE_KP'" \
    "Expected '$KEYPAIR_NAME' — terminate and re-launch with the correct key pair"
fi

# ------------------------------------------------------------------------------
# Check 9 — Instance is associated with the correct security group
# ------------------------------------------------------------------------------
echo "Checking security group association..."
if [ -n "$SG_ID" ]; then
  SG_MATCH=$(echo "$INSTANCE_JSON" | \
    jq -r --arg sgid "$SG_ID" \
    '.SecurityGroups[] | select(.GroupId == $sgid) | .GroupId' 2>/dev/null | head -1)

  if [ "$SG_MATCH" = "$SG_ID" ]; then
    pass "Instance is associated with security group '$SG_NAME'"
  else
    fail "Instance is not associated with security group '$SG_NAME'" \
      "The security group '$SG_NAME' ($SG_ID) is not attached to this instance"
  fi
else
  fail "Cannot check security group association" \
    "Security group '$SG_NAME' was not found"
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
  echo " 🎉 Perfect score! All kata-108 requirements met."
elif [ "$PASS" -ge 7 ]; then
  echo " 🔧 Almost there — review the failed checks above."
else
  echo " 📖 Keep going — consult HINTS.md for guidance."
fi
echo ""