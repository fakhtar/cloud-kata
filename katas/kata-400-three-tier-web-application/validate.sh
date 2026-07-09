#!/bin/bash
# =============================================================================
# CloudKata — kata-400 Validator
# kata:    kata-400
# title:   Three-Tier Web App: CloudFront, ALB, EC2 & RDS in Multi-AZ
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

VPC_NAME="kata-400-VPC"
ALB_NAME="kata-400-ALB"
ASG_NAME="kata-400-ASG"
DB_NAME="kata-400-DB"
ALB_SG_NAME="kata-400-ALB-SG"
EC2_SG_NAME="kata-400-EC2-SG"
DB_SG_NAME="kata-400-DB-SG"
MIN_AZ=2
MIN_ASG_SIZE=2

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
echo " CloudKata Validator — kata-400"
echo " Three-Tier Web App: CloudFront, ALB, EC2 & RDS in Multi-AZ"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Check 1 — VPC exists
# ------------------------------------------------------------------------------
echo "Checking VPC existence..."
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=${VPC_NAME}" \
  --query 'Vpcs[0].VpcId' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$VPC_ID" != "NOT_FOUND" ] && [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
  pass "VPC '${VPC_NAME}' exists (ID: ${VPC_ID})"
else
  fail "VPC '${VPC_NAME}'" "VPC not found — ensure a VPC tagged Name=${VPC_NAME} exists"
  echo ""
  echo "  Cannot continue without a valid VPC. Please create it and re-run."
  echo ""
  echo "=================================================="
  echo " Results: 0/$((TOTAL)) checks passed (0%)"
  echo "=================================================="
  exit 1
fi

# ------------------------------------------------------------------------------
# Build subnet/route-table classification (used by Checks 2-4 and later checks)
# ------------------------------------------------------------------------------
echo "Classifying subnets by route table..."
SUBNETS_JSON=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=${VPC_ID}" \
  --output json 2>/dev/null || echo '{"Subnets":[]}')

RTS_JSON=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=${VPC_ID}" \
  --output json 2>/dev/null || echo '{"RouteTables":[]}')

SUBNET_CLASSIFICATION=$(jq -n \
  --argjson subs "$(echo "$SUBNETS_JSON" | jq '.Subnets')" \
  --argjson rts "$(echo "$RTS_JSON" | jq '.RouteTables')" \
  '
  $subs | map(
    . as $s
    | ([$rts[] | select(.Associations[]?.SubnetId == $s.SubnetId)] | first) as $explicit
    | ([$rts[] | select(.Associations[]?.Main == true)] | first) as $main
    | ($explicit // $main) as $rt
    | {
        subnetId: $s.SubnetId,
        az: $s.AvailabilityZone,
        isPublic: (($rt.Routes // []) | any(.DestinationCidrBlock == "0.0.0.0/0" and ((.GatewayId // "") | startswith("igw-")))),
        hasNat: (($rt.Routes // []) | any(.DestinationCidrBlock == "0.0.0.0/0" and ((.NatGatewayId // "") | startswith("nat-"))))
      }
  )
  ' 2>/dev/null || echo "[]")

PUBLIC_AZ_COUNT=$(echo "$SUBNET_CLASSIFICATION" | jq '[.[] | select(.isPublic) | .az] | unique | length' 2>/dev/null || echo "0")
PRIVATE_AZ_COUNT=$(echo "$SUBNET_CLASSIFICATION" | jq '[.[] | select(.isPublic|not) | .az] | unique | length' 2>/dev/null || echo "0")
PRIVATE_TOTAL_COUNT=$(echo "$SUBNET_CLASSIFICATION" | jq '[.[] | select(.isPublic|not)] | length' 2>/dev/null || echo "0")
PRIVATE_NAT_COUNT=$(echo "$SUBNET_CLASSIFICATION" | jq '[.[] | select((.isPublic|not) and .hasNat)] | length' 2>/dev/null || echo "0")
PUBLIC_SUBNET_IDS=$(echo "$SUBNET_CLASSIFICATION" | jq -r '[.[] | select(.isPublic) | .subnetId]')
PRIVATE_SUBNET_IDS=$(echo "$SUBNET_CLASSIFICATION" | jq -r '[.[] | select(.isPublic|not) | .subnetId]')

# ------------------------------------------------------------------------------
# Check 2 — Public subnets span 2+ AZs and route to an Internet Gateway
# ------------------------------------------------------------------------------
echo "Checking public subnet topology..."
if [ "$PUBLIC_AZ_COUNT" -ge "$MIN_AZ" ] 2>/dev/null; then
  pass "Public subnets span ${PUBLIC_AZ_COUNT} Availability Zones and route to an Internet Gateway (minimum: ${MIN_AZ})"
else
  fail "Public subnet topology" "Found public subnets in ${PUBLIC_AZ_COUNT} AZ(s) but minimum is ${MIN_AZ} — ensure at least ${MIN_AZ} subnets have a 0.0.0.0/0 route to an Internet Gateway"
fi

# ------------------------------------------------------------------------------
# Check 3 — Private subnets span 2+ AZs with no direct internet route
# ------------------------------------------------------------------------------
echo "Checking private subnet topology..."
if [ "$PRIVATE_AZ_COUNT" -ge "$MIN_AZ" ] 2>/dev/null; then
  pass "Private subnets span ${PRIVATE_AZ_COUNT} Availability Zones with no direct route to an Internet Gateway (minimum: ${MIN_AZ})"
else
  fail "Private subnet topology" "Found private subnets in ${PRIVATE_AZ_COUNT} AZ(s) but minimum is ${MIN_AZ}"
fi

# ------------------------------------------------------------------------------
# Check 4 — Private subnets route outbound via a NAT Gateway
# ------------------------------------------------------------------------------
echo "Checking private subnet outbound (NAT) access..."
if [ "$PRIVATE_TOTAL_COUNT" -gt 0 ] 2>/dev/null && [ "$PRIVATE_NAT_COUNT" -eq "$PRIVATE_TOTAL_COUNT" ] 2>/dev/null; then
  pass "All ${PRIVATE_TOTAL_COUNT} private subnet(s) route 0.0.0.0/0 outbound through a NAT Gateway"
else
  fail "Private subnet NAT access" "${PRIVATE_NAT_COUNT}/${PRIVATE_TOTAL_COUNT} private subnets route outbound via a NAT Gateway — instances need patch/update access without being directly internet-reachable"
fi

# ------------------------------------------------------------------------------
# Look up security groups (used by Checks 5-7)
# ------------------------------------------------------------------------------
ALB_SG_JSON=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=${ALB_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
  --output json 2>/dev/null || echo '{"SecurityGroups":[]}')
ALB_SG_ID=$(echo "$ALB_SG_JSON" | jq -r '.SecurityGroups[0].GroupId // "NOT_FOUND"')

EC2_SG_JSON=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=${EC2_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
  --output json 2>/dev/null || echo '{"SecurityGroups":[]}')
EC2_SG_ID=$(echo "$EC2_SG_JSON" | jq -r '.SecurityGroups[0].GroupId // "NOT_FOUND"')

DB_SG_JSON=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=${DB_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
  --output json 2>/dev/null || echo '{"SecurityGroups":[]}')
DB_SG_ID=$(echo "$DB_SG_JSON" | jq -r '.SecurityGroups[0].GroupId // "NOT_FOUND"')

# ------------------------------------------------------------------------------
# Check 5 — ALB security group allows inbound web traffic from the internet
# ------------------------------------------------------------------------------
echo "Checking ALB security group '${ALB_SG_NAME}'..."
if [ "$ALB_SG_ID" != "NOT_FOUND" ] && [ -n "$ALB_SG_ID" ]; then
  HAS_PUBLIC_INGRESS=$(echo "$ALB_SG_JSON" | jq \
    '[.SecurityGroups[0].IpPermissions[]? | select((.FromPort==80 or .FromPort==443) and (.IpRanges[]?.CidrIp=="0.0.0.0/0"))] | length > 0')
  if [ "$HAS_PUBLIC_INGRESS" = "true" ]; then
    pass "Security group '${ALB_SG_NAME}' allows inbound web traffic (80/443) from 0.0.0.0/0"
  else
    fail "ALB security group ingress" "'${ALB_SG_NAME}' does not allow inbound 80/443 from 0.0.0.0/0"
  fi
else
  fail "ALB security group '${ALB_SG_NAME}'" "Security group not found — ensure a security group named exactly '${ALB_SG_NAME}' exists in ${VPC_NAME}"
fi

# ------------------------------------------------------------------------------
# Check 6 — EC2 security group allows inbound only from the ALB security group
# ------------------------------------------------------------------------------
echo "Checking EC2 security group '${EC2_SG_NAME}'..."
if [ "$EC2_SG_ID" != "NOT_FOUND" ] && [ -n "$EC2_SG_ID" ] && [ "$ALB_SG_ID" != "NOT_FOUND" ]; then
  HAS_OPEN_CIDR=$(echo "$EC2_SG_JSON" | jq \
    '[.SecurityGroups[0].IpPermissions[]? | select(.IpRanges[]?.CidrIp=="0.0.0.0/0")] | length > 0')
  HAS_ALB_SOURCE=$(echo "$EC2_SG_JSON" | jq \
    --arg alb "$ALB_SG_ID" \
    '[.SecurityGroups[0].IpPermissions[]? | select(.UserIdGroupPairs[]?.GroupId==$alb)] | length > 0')
  if [ "$HAS_OPEN_CIDR" = "false" ] && [ "$HAS_ALB_SOURCE" = "true" ]; then
    pass "Security group '${EC2_SG_NAME}' allows inbound only from '${ALB_SG_NAME}' (no 0.0.0.0/0 ingress)"
  else
    fail "EC2 security group ingress" "'${EC2_SG_NAME}' must allow inbound only from ${ALB_SG_NAME} — found open CIDR ingress: ${HAS_OPEN_CIDR}, ALB SG as source: ${HAS_ALB_SOURCE}"
  fi
else
  fail "EC2 security group '${EC2_SG_NAME}'" "Cannot check — security group or its ALB SG dependency was not found"
fi

# ------------------------------------------------------------------------------
# Check 7 — DB security group allows inbound only from the EC2 security group
# ------------------------------------------------------------------------------
echo "Checking DB security group '${DB_SG_NAME}'..."
if [ "$DB_SG_ID" != "NOT_FOUND" ] && [ -n "$DB_SG_ID" ] && [ "$EC2_SG_ID" != "NOT_FOUND" ]; then
  HAS_OPEN_CIDR=$(echo "$DB_SG_JSON" | jq \
    '[.SecurityGroups[0].IpPermissions[]? | select(.IpRanges[]?.CidrIp=="0.0.0.0/0")] | length > 0')
  HAS_EC2_SOURCE=$(echo "$DB_SG_JSON" | jq \
    --arg ec2 "$EC2_SG_ID" \
    '[.SecurityGroups[0].IpPermissions[]? | select(.UserIdGroupPairs[]?.GroupId==$ec2)] | length > 0')
  if [ "$HAS_OPEN_CIDR" = "false" ] && [ "$HAS_EC2_SOURCE" = "true" ]; then
    pass "Security group '${DB_SG_NAME}' allows inbound only from '${EC2_SG_NAME}' (no 0.0.0.0/0 ingress)"
  else
    fail "DB security group ingress" "'${DB_SG_NAME}' must allow inbound only from ${EC2_SG_NAME} — found open CIDR ingress: ${HAS_OPEN_CIDR}, EC2 SG as source: ${HAS_EC2_SOURCE}"
  fi
else
  fail "DB security group '${DB_SG_NAME}'" "Cannot check — security group or its EC2 SG dependency was not found"
fi

# ------------------------------------------------------------------------------
# Check 8 — ALB is internet-facing and spans 2+ public AZs
# ------------------------------------------------------------------------------
echo "Checking ALB '${ALB_NAME}'..."
ALB_JSON=$(aws elbv2 describe-load-balancers \
  --names "${ALB_NAME}" \
  --output json 2>/dev/null || echo "NOT_FOUND")

if [ "$ALB_JSON" != "NOT_FOUND" ] && [ "$(echo "$ALB_JSON" | jq '.LoadBalancers | length')" -gt 0 ]; then
  ALB_ARN=$(echo "$ALB_JSON" | jq -r '.LoadBalancers[0].LoadBalancerArn')
  ALB_SCHEME=$(echo "$ALB_JSON" | jq -r '.LoadBalancers[0].Scheme')
  ALB_AZ_COUNT=$(echo "$ALB_JSON" | jq '[.LoadBalancers[0].AvailabilityZones[].ZoneName] | unique | length')

  if [ "$ALB_SCHEME" = "internet-facing" ] && [ "$ALB_AZ_COUNT" -ge "$MIN_AZ" ] 2>/dev/null; then
    pass "ALB '${ALB_NAME}' is internet-facing and spans ${ALB_AZ_COUNT} Availability Zones"
  else
    fail "ALB '${ALB_NAME}' configuration" "Scheme='${ALB_SCHEME}' (expected internet-facing), AZ count=${ALB_AZ_COUNT} (minimum ${MIN_AZ})"
  fi
else
  fail "ALB '${ALB_NAME}'" "Load balancer not found — ensure an ALB named exactly '${ALB_NAME}' exists"
  ALB_ARN="NOT_FOUND"
fi

# ------------------------------------------------------------------------------
# Check 9 — ALB target group has at least one healthy target
# ------------------------------------------------------------------------------
echo "Checking target group health..."
if [ "${ALB_ARN:-NOT_FOUND}" != "NOT_FOUND" ]; then
  TG_ARN=$(aws elbv2 describe-target-groups \
    --load-balancer-arn "$ALB_ARN" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text 2>/dev/null || echo "NOT_FOUND")

  if [ "$TG_ARN" != "NOT_FOUND" ] && [ "$TG_ARN" != "None" ] && [ -n "$TG_ARN" ]; then
    HEALTHY_COUNT=$(aws elbv2 describe-target-health \
      --target-group-arn "$TG_ARN" \
      --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" \
      --output text 2>/dev/null || echo "0")

    if [ "$HEALTHY_COUNT" -ge 1 ] 2>/dev/null; then
      pass "Target group has ${HEALTHY_COUNT} healthy target(s)"
    else
      fail "Target group health" "No healthy targets found — check that ASG instances have passed the target group health check"
    fi
  else
    fail "Target group" "No target group found attached to '${ALB_NAME}'"
    TG_ARN="NOT_FOUND"
  fi
else
  fail "Target group health" "Cannot check — ALB '${ALB_NAME}' was not found"
  TG_ARN="NOT_FOUND"
fi

# ------------------------------------------------------------------------------
# Check 10 — ASG spans 2+ AZs with minimum 2 instances in private subnets
# ------------------------------------------------------------------------------
echo "Checking Auto Scaling group '${ASG_NAME}'..."
ASG_JSON=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "${ASG_NAME}" \
  --output json 2>/dev/null || echo "NOT_FOUND")

if [ "$ASG_JSON" != "NOT_FOUND" ] && [ "$(echo "$ASG_JSON" | jq '.AutoScalingGroups | length')" -gt 0 ]; then
  ASG_AZ_COUNT=$(echo "$ASG_JSON" | jq '[.AutoScalingGroups[0].Instances[].AvailabilityZone] | unique | length')
  ASG_MIN_SIZE=$(echo "$ASG_JSON" | jq '.AutoScalingGroups[0].MinSize')
  ASG_SUBNET_IDS=$(echo "$ASG_JSON" | jq -r '.AutoScalingGroups[0].VPCZoneIdentifier // ""' | tr ',' '\n')
  ASG_SUBNETS_ALL_PRIVATE="true"
  for SUBNET_ID in $ASG_SUBNET_IDS; do
    IS_PRIVATE=$(echo "$PRIVATE_SUBNET_IDS" | jq --arg s "$SUBNET_ID" 'index($s) != null')
    if [ "$IS_PRIVATE" != "true" ]; then
      ASG_SUBNETS_ALL_PRIVATE="false"
    fi
  done

  if [ "$ASG_AZ_COUNT" -ge "$MIN_AZ" ] 2>/dev/null && [ "$ASG_MIN_SIZE" -ge "$MIN_ASG_SIZE" ] 2>/dev/null && [ "$ASG_SUBNETS_ALL_PRIVATE" = "true" ]; then
    pass "ASG '${ASG_NAME}' spans ${ASG_AZ_COUNT} AZs, MinSize=${ASG_MIN_SIZE}, deployed in private subnets"
  else
    fail "ASG '${ASG_NAME}' configuration" "AZ count=${ASG_AZ_COUNT} (min ${MIN_AZ}), MinSize=${ASG_MIN_SIZE} (min ${MIN_ASG_SIZE}), all subnets private=${ASG_SUBNETS_ALL_PRIVATE}"
  fi
else
  fail "ASG '${ASG_NAME}'" "Auto Scaling group not found — ensure a group named exactly '${ASG_NAME}' exists"
  ASG_JSON='{"AutoScalingGroups":[]}'
fi

# ------------------------------------------------------------------------------
# Check 11 — ASG instances are registered as healthy targets behind the ALB
# ------------------------------------------------------------------------------
echo "Checking ASG-to-target-group registration..."
if [ "$TG_ARN" != "NOT_FOUND" ] && [ "$(echo "$ASG_JSON" | jq '.AutoScalingGroups | length')" -gt 0 ]; then
  ASG_INSTANCE_IDS=$(echo "$ASG_JSON" | jq -r '[.AutoScalingGroups[0].Instances[].InstanceId]')
  HEALTHY_TARGET_IDS=$(aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --query "TargetHealthDescriptions[?TargetHealth.State=='healthy'].Target.Id" \
    --output json 2>/dev/null || echo "[]")

  UNREGISTERED_COUNT=$(jq -n \
    --argjson asg "$ASG_INSTANCE_IDS" \
    --argjson healthy "$HEALTHY_TARGET_IDS" \
    '[$asg[] | select(. as $i | ($healthy | index($i)) == null)] | length')
  ASG_INSTANCE_COUNT=$(echo "$ASG_INSTANCE_IDS" | jq 'length')

  if [ "$ASG_INSTANCE_COUNT" -gt 0 ] 2>/dev/null && [ "$UNREGISTERED_COUNT" -eq 0 ] 2>/dev/null; then
    pass "All ${ASG_INSTANCE_COUNT} ASG instance(s) are healthy targets behind '${ALB_NAME}'"
  else
    fail "ASG-to-ALB registration" "${UNREGISTERED_COUNT}/${ASG_INSTANCE_COUNT} ASG instances are not healthy targets — check target group attachment"
  fi
else
  fail "ASG-to-ALB registration" "Cannot check — target group or ASG was not found"
fi

# ------------------------------------------------------------------------------
# Check 12 — RDS instance is Multi-AZ and available
# ------------------------------------------------------------------------------
echo "Checking RDS instance '${DB_NAME}'..."
DB_JSON=$(aws rds describe-db-instances \
  --db-instance-identifier "${DB_NAME}" \
  --output json 2>/dev/null || echo "NOT_FOUND")

if [ "$DB_JSON" != "NOT_FOUND" ] && [ "$(echo "$DB_JSON" | jq '.DBInstances | length')" -gt 0 ]; then
  DB_MULTI_AZ=$(echo "$DB_JSON" | jq -r '.DBInstances[0].MultiAZ')
  DB_STATUS=$(echo "$DB_JSON" | jq -r '.DBInstances[0].DBInstanceStatus')
  DB_PUBLIC=$(echo "$DB_JSON" | jq -r '.DBInstances[0].PubliclyAccessible')
  DB_SUBNET_GROUP_NAME=$(echo "$DB_JSON" | jq -r '.DBInstances[0].DBSubnetGroup.DBSubnetGroupName')

  if [ "$DB_MULTI_AZ" = "true" ] && [ "$DB_STATUS" = "available" ]; then
    pass "RDS instance '${DB_NAME}' is Multi-AZ and available"
  else
    fail "RDS instance '${DB_NAME}' status" "MultiAZ=${DB_MULTI_AZ} (expected true), Status=${DB_STATUS} (expected available)"
  fi
else
  fail "RDS instance '${DB_NAME}'" "DB instance not found — ensure an RDS instance named exactly '${DB_NAME}' exists"
  DB_PUBLIC="NOT_FOUND"
  DB_SUBNET_GROUP_NAME="NOT_FOUND"
fi

# ------------------------------------------------------------------------------
# Check 13 — RDS subnet group is private-only, spans 2+ AZs, not publicly accessible
# ------------------------------------------------------------------------------
echo "Checking RDS network isolation..."
if [ "$DB_SUBNET_GROUP_NAME" != "NOT_FOUND" ] && [ -n "$DB_SUBNET_GROUP_NAME" ]; then
  SUBNET_GROUP_JSON=$(aws rds describe-db-subnet-groups \
    --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
    --output json 2>/dev/null || echo "NOT_FOUND")

  if [ "$SUBNET_GROUP_JSON" != "NOT_FOUND" ]; then
    DB_SUBNET_IDS=$(echo "$SUBNET_GROUP_JSON" | jq -r '[.DBSubnetGroups[0].Subnets[].SubnetIdentifier]')
    DB_SUBNET_AZ_COUNT=$(echo "$SUBNET_GROUP_JSON" | jq '[.DBSubnetGroups[0].Subnets[].SubnetAvailabilityZone.Name] | unique | length')

    DB_SUBNETS_ALL_PRIVATE="true"
    for SUBNET_ID in $(echo "$DB_SUBNET_IDS" | jq -r '.[]'); do
      IS_PRIVATE=$(echo "$PRIVATE_SUBNET_IDS" | jq --arg s "$SUBNET_ID" 'index($s) != null')
      if [ "$IS_PRIVATE" != "true" ]; then
        DB_SUBNETS_ALL_PRIVATE="false"
      fi
    done

    if [ "$DB_SUBNET_AZ_COUNT" -ge "$MIN_AZ" ] 2>/dev/null && [ "$DB_SUBNETS_ALL_PRIVATE" = "true" ] && [ "$DB_PUBLIC" = "false" ]; then
      pass "RDS subnet group is private-only, spans ${DB_SUBNET_AZ_COUNT} AZs, and '${DB_NAME}' is not publicly accessible"
    else
      fail "RDS network isolation" "Subnet AZ count=${DB_SUBNET_AZ_COUNT} (min ${MIN_AZ}), all subnets private=${DB_SUBNETS_ALL_PRIVATE}, PubliclyAccessible=${DB_PUBLIC} (expected false)"
    fi
  else
    fail "RDS network isolation" "Could not describe DB subnet group '${DB_SUBNET_GROUP_NAME}'"
  fi
else
  fail "RDS network isolation" "Cannot check — DB instance '${DB_NAME}' was not found"
fi

# ------------------------------------------------------------------------------
# Check 14 — CloudFront distribution is Deployed, uses the ALB as origin, and
# enforces HTTPS on viewer traffic
# ------------------------------------------------------------------------------
echo "Checking CloudFront distribution..."
if [ "${ALB_JSON:-NOT_FOUND}" != "NOT_FOUND" ] && [ "$(echo "$ALB_JSON" | jq '.LoadBalancers | length')" -gt 0 ]; then
  ALB_DNS_NAME=$(echo "$ALB_JSON" | jq -r '.LoadBalancers[0].DNSName')

  DIST_JSON=$(aws cloudfront list-distributions --output json 2>/dev/null || echo "NOT_FOUND")

  if [ "$DIST_JSON" != "NOT_FOUND" ]; then
    MATCHING_DIST=$(echo "$DIST_JSON" | jq \
      --arg alb "$ALB_DNS_NAME" \
      '[.DistributionList.Items[]? | select([.Origins.Items[]?.DomainName] | index($alb) != null)] | first')

    if [ "$MATCHING_DIST" != "null" ] && [ -n "$MATCHING_DIST" ]; then
      DIST_STATUS=$(echo "$MATCHING_DIST" | jq -r '.Status')
      DIST_VPP=$(echo "$MATCHING_DIST" | jq -r '.DefaultCacheBehavior.ViewerProtocolPolicy')

      if [ "$DIST_STATUS" = "Deployed" ] && [ "$DIST_VPP" = "redirect-to-https" ]; then
        pass "CloudFront distribution is Deployed with '${ALB_NAME}' as origin and enforces HTTPS on viewer traffic"
      else
        fail "CloudFront distribution configuration" "Status=${DIST_STATUS} (expected Deployed), ViewerProtocolPolicy=${DIST_VPP} (expected redirect-to-https)"
      fi
    else
      fail "CloudFront distribution" "No distribution found with an origin matching ALB DNS name '${ALB_DNS_NAME}'"
    fi
  else
    fail "CloudFront distribution" "Could not list CloudFront distributions"
  fi
else
  fail "CloudFront distribution" "Cannot check — ALB '${ALB_NAME}' was not found to compare origins against"
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
  echo " 🎉 Perfect score! All kata-400 requirements met."
  echo ""
fi

if [ "$FAIL" -gt 0 ]; then
  echo " Review the failed checks above, fix your infrastructure,"
  echo " and re-run this validator."
  echo ""
  exit 1
fi