#!/bin/bash

# ==============================================================================
# CloudKata Validator — kata-104
# VPC Basics: Networking Constructs & Routing
# ==============================================================================

VPC_NAME="kata-104-VPC"
VPC_CIDR="10.104.0.0/16"
SUBNET1_NAME="kata-104-PublicSubnet1"
SUBNET1_CIDR="10.104.1.0/24"
SUBNET2_NAME="kata-104-PublicSubnet2"
SUBNET2_CIDR="10.104.2.0/24"
IGW_NAME="kata-104-IGW"
RT_NAME="kata-104-PublicRouteTable"

PASS=0
FAIL=0

pass() { echo "✅ PASS — $1"; ((PASS++)); }
fail() { echo "❌ FAIL — $1"; ((FAIL++)); }

echo ""
echo "=================================================="
echo " CloudKata Validator — kata-104"
echo " VPC Basics: Networking Constructs & Routing"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Check 1 — VPC exists with correct name and CIDR (hard gate)
# ------------------------------------------------------------------------------
echo "Checking VPC..."
VPC_JSON=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=${VPC_NAME}" \
  --query 'Vpcs[0]' \
  --output json 2>/dev/null)

VPC_ID=$(echo "$VPC_JSON" | jq -r '.VpcId // empty')

if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "null" ]; then
  echo "❌ FAIL — VPC '$VPC_NAME' not found. Cannot continue."
  echo ""
  echo "=================================================="
  echo " Results: 0/10 checks passed (0%)"
  echo "=================================================="
  exit 1
fi

VPC_CIDR_ACTUAL=$(echo "$VPC_JSON" | jq -r '.CidrBlock')
if [ "$VPC_CIDR_ACTUAL" = "$VPC_CIDR" ]; then
  pass "VPC '$VPC_NAME' exists with CIDR $VPC_CIDR"
else
  fail "VPC '$VPC_NAME' exists but CIDR is '$VPC_CIDR_ACTUAL' — expected '$VPC_CIDR'"
fi

# ------------------------------------------------------------------------------
# Check 2 — DNS support enabled
# ------------------------------------------------------------------------------
echo "Checking DNS support..."
DNS_SUPPORT=$(aws ec2 describe-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --attribute enableDnsSupport \
  --query 'EnableDnsSupport.Value' \
  --output text 2>/dev/null | tr '[:upper:]' '[:lower:]')

[ "$DNS_SUPPORT" = "true" ] && \
  pass "DNS support is enabled" || \
  fail "DNS support is not enabled"

# ------------------------------------------------------------------------------
# Check 3 — DNS hostnames enabled
# ------------------------------------------------------------------------------
echo "Checking DNS hostnames..."
DNS_HOSTNAMES=$(aws ec2 describe-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --attribute enableDnsHostnames \
  --query 'EnableDnsHostnames.Value' \
  --output text 2>/dev/null | tr '[:upper:]' '[:lower:]')

[ "$DNS_HOSTNAMES" = "true" ] && \
  pass "DNS hostnames are enabled" || \
  fail "DNS hostnames are not enabled"

# ------------------------------------------------------------------------------
# Check 4 — Subnet 1 exists with correct CIDR
# ------------------------------------------------------------------------------
echo "Checking subnets..."
SUBNET1_JSON=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=${SUBNET1_NAME}" \
            "Name=vpc-id,Values=${VPC_ID}" \
  --query 'Subnets[0]' \
  --output json 2>/dev/null)

SUBNET1_ID=$(echo "$SUBNET1_JSON" | jq -r '.SubnetId // empty')
SUBNET1_CIDR_ACTUAL=$(echo "$SUBNET1_JSON" | jq -r '.CidrBlock // empty')
SUBNET1_AZ=$(echo "$SUBNET1_JSON" | jq -r '.AvailabilityZone // empty')

if [ -z "$SUBNET1_ID" ] || [ "$SUBNET1_ID" = "null" ]; then
  fail "Subnet '$SUBNET1_NAME' not found in VPC"
  SUBNET1_AZ=""
elif [ "$SUBNET1_CIDR_ACTUAL" = "$SUBNET1_CIDR" ]; then
  pass "Subnet '$SUBNET1_NAME' exists with correct CIDR $SUBNET1_CIDR"
else
  fail "Subnet '$SUBNET1_NAME' CIDR is '$SUBNET1_CIDR_ACTUAL' — expected '$SUBNET1_CIDR'"
fi

# ------------------------------------------------------------------------------
# Check 5 — Subnet 2 exists with correct CIDR
# ------------------------------------------------------------------------------
SUBNET2_JSON=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=${SUBNET2_NAME}" \
            "Name=vpc-id,Values=${VPC_ID}" \
  --query 'Subnets[0]' \
  --output json 2>/dev/null)

SUBNET2_ID=$(echo "$SUBNET2_JSON" | jq -r '.SubnetId // empty')
SUBNET2_CIDR_ACTUAL=$(echo "$SUBNET2_JSON" | jq -r '.CidrBlock // empty')
SUBNET2_AZ=$(echo "$SUBNET2_JSON" | jq -r '.AvailabilityZone // empty')

if [ -z "$SUBNET2_ID" ] || [ "$SUBNET2_ID" = "null" ]; then
  fail "Subnet '$SUBNET2_NAME' not found in VPC"
  SUBNET2_AZ=""
elif [ "$SUBNET2_CIDR_ACTUAL" = "$SUBNET2_CIDR" ]; then
  pass "Subnet '$SUBNET2_NAME' exists with correct CIDR $SUBNET2_CIDR"
else
  fail "Subnet '$SUBNET2_NAME' CIDR is '$SUBNET2_CIDR_ACTUAL' — expected '$SUBNET2_CIDR'"
fi

# ------------------------------------------------------------------------------
# Check 6 — Subnets are in different availability zones
# ------------------------------------------------------------------------------
echo "Checking availability zones..."
if [ -n "$SUBNET1_AZ" ] && [ -n "$SUBNET2_AZ" ]; then
  if [ "$SUBNET1_AZ" != "$SUBNET2_AZ" ]; then
    pass "Subnets are in different availability zones ($SUBNET1_AZ, $SUBNET2_AZ)"
  else
    fail "Both subnets are in the same availability zone ($SUBNET1_AZ) — must be different"
  fi
else
  fail "Cannot check availability zones — one or both subnets not found"
fi

# ------------------------------------------------------------------------------
# Check 7 — Internet gateway exists and is attached to the VPC
# ------------------------------------------------------------------------------
echo "Checking internet gateway..."
IGW_JSON=$(aws ec2 describe-internet-gateways \
  --filters "Name=tag:Name,Values=${IGW_NAME}" \
  --query 'InternetGateways[0]' \
  --output json 2>/dev/null)

IGW_ID=$(echo "$IGW_JSON" | jq -r '.InternetGatewayId // empty')

if [ -z "$IGW_ID" ] || [ "$IGW_ID" = "null" ]; then
  fail "Internet gateway '$IGW_NAME' not found"
  IGW_ID=""
else
  ATTACHED_VPC=$(echo "$IGW_JSON" | \
    jq -r --arg vpc "$VPC_ID" \
    '.Attachments[] | select(.VpcId == $vpc) | .State' 2>/dev/null)

  if [ "$ATTACHED_VPC" = "available" ]; then
    pass "Internet gateway '$IGW_NAME' exists and is attached to the VPC"
  else
    fail "Internet gateway '$IGW_NAME' exists but is not attached to '$VPC_NAME'"
  fi
fi

# ------------------------------------------------------------------------------
# Check 8 — Route table exists
# ------------------------------------------------------------------------------
echo "Checking route table..."
RT_JSON=$(aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=${RT_NAME}" \
            "Name=vpc-id,Values=${VPC_ID}" \
  --query 'RouteTables[0]' \
  --output json 2>/dev/null)

RT_ID=$(echo "$RT_JSON" | jq -r '.RouteTableId // empty')

if [ -z "$RT_ID" ] || [ "$RT_ID" = "null" ]; then
  fail "Route table '$RT_NAME' not found in VPC"
  RT_ID=""
else
  pass "Route table '$RT_NAME' exists"
fi

# ------------------------------------------------------------------------------
# Check 9 — Default route 0.0.0.0/0 points to the internet gateway
# ------------------------------------------------------------------------------
echo "Checking default route..."
if [ -n "$RT_ID" ] && [ -n "$IGW_ID" ]; then
  DEFAULT_ROUTE_TARGET=$(echo "$RT_JSON" | \
    jq -r '.Routes[] | select(.DestinationCidrBlock == "0.0.0.0/0") | .GatewayId' \
    2>/dev/null)

  if [ "$DEFAULT_ROUTE_TARGET" = "$IGW_ID" ]; then
    pass "Default route 0.0.0.0/0 points to the internet gateway"
  elif [ -n "$DEFAULT_ROUTE_TARGET" ]; then
    fail "Default route 0.0.0.0/0 exists but points to '$DEFAULT_ROUTE_TARGET' not the IGW"
  else
    fail "No default route 0.0.0.0/0 found in route table '$RT_NAME'"
  fi
else
  fail "Cannot check default route — route table or internet gateway not found"
fi

# ------------------------------------------------------------------------------
# Check 10 — Both subnets are associated with the route table
# ------------------------------------------------------------------------------
echo "Checking subnet associations..."
if [ -n "$RT_ID" ] && [ -n "$SUBNET1_ID" ] && [ -n "$SUBNET2_ID" ]; then
  ASSOCIATED_SUBNETS=$(echo "$RT_JSON" | \
    jq -r '.Associations[].SubnetId // empty' 2>/dev/null)

  SUBNET1_ASSOCIATED=false
  SUBNET2_ASSOCIATED=false

  while IFS= read -r subnet; do
    [ "$subnet" = "$SUBNET1_ID" ] && SUBNET1_ASSOCIATED=true
    [ "$subnet" = "$SUBNET2_ID" ] && SUBNET2_ASSOCIATED=true
  done <<< "$ASSOCIATED_SUBNETS"

  if [ "$SUBNET1_ASSOCIATED" = true ] && [ "$SUBNET2_ASSOCIATED" = true ]; then
    pass "Both subnets are associated with the route table"
  elif [ "$SUBNET1_ASSOCIATED" = false ] && [ "$SUBNET2_ASSOCIATED" = false ]; then
    fail "Neither subnet is associated with route table '$RT_NAME'"
  elif [ "$SUBNET1_ASSOCIATED" = false ]; then
    fail "Subnet '$SUBNET1_NAME' is not associated with route table '$RT_NAME'"
  else
    fail "Subnet '$SUBNET2_NAME' is not associated with route table '$RT_NAME'"
  fi
else
  fail "Cannot check subnet associations — route table or subnets not found"
fi

# ------------------------------------------------------------------------------
# Results
# ------------------------------------------------------------------------------
PCT=$(( (PASS * 100) / 10 ))

echo ""
echo "=================================================="
echo " Results: $PASS/10 checks passed ($PCT%)"
echo "=================================================="

if [ "$PASS" -eq 10 ]; then
  echo " 🎉 Perfect score! All kata-104 requirements met."
elif [ "$PASS" -ge 7 ]; then
  echo " 🔧 Almost there — review the failed checks above."
else
  echo " 📖 Keep going — consult HINTS.md for guidance."
fi
echo ""