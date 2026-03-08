#!/bin/bash
# =============================================================================
# CloudKata — kata-XXX Cleanup
# kata:    kata-XXX
# title:   Your Kata Title
# =============================================================================
#
# IMPORTANT: Follow these steps in order.
#
# Step 1 — Delete CloudFormation stacks first (if applicable)
#   If you deployed solution.yml or prereqs.yml, delete those stacks via
#   the AWS CloudFormation console or CLI before running this script.
#   Wait for stack deletion to complete before proceeding.
#
#   Via CLI:
#     aws cloudformation delete-stack --stack-name YOUR-STACK-NAME
#     aws cloudformation wait stack-delete-complete --stack-name YOUR-STACK-NAME
#
# Step 2 — Run this script
#   This script removes any resources not handled by CloudFormation stack
#   deletion, or resources you created manually without the solution template.
#
#   Usage:
#     sed -i 's/\r//' cleanup.sh
#     chmod +x cleanup.sh
#     ./cleanup.sh
#
# Step 3 — Verify in the AWS Console
#   Confirm all resources prefixed with kata-XXX- have been removed.
#
# =============================================================================

echo ""
echo "=================================================="
echo " CloudKata Cleanup — kata-XXX"
echo " Your Kata Title"
echo "=================================================="
echo ""
echo "NOTE: Ensure CloudFormation stacks have been deleted before"
echo "running this script. See the header comments for instructions."
echo ""

# ------------------------------------------------------------------------------
# Delete resources in reverse dependency order.
# Resources that depend on others must be deleted first.
# All deletions target kata-XXX- prefixed resources only.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Example: Delete a resource
# Replace with actual AWS CLI delete commands for your kata resources.
# ------------------------------------------------------------------------------
echo "Deleting kata-XXX-ResourceName..."
aws some-service delete-something \
  --name "kata-XXX-ResourceName" 2>/dev/null \
  && echo "✅ Deleted kata-XXX-ResourceName" \
  || echo "⚠️  kata-XXX-ResourceName not found or already deleted"

echo ""

# ------------------------------------------------------------------------------
# Example: Delete another resource
# ------------------------------------------------------------------------------
echo "Deleting kata-XXX-AnotherResourceName..."
aws some-service delete-something \
  --name "kata-XXX-AnotherResourceName" 2>/dev/null \
  && echo "✅ Deleted kata-XXX-AnotherResourceName" \
  || echo "⚠️  kata-XXX-AnotherResourceName not found or already deleted"

echo ""

# ------------------------------------------------------------------------------
# Add additional deletions following the same pattern.
# Delete in reverse dependency order — dependents before dependencies.
# ------------------------------------------------------------------------------

echo "=================================================="
echo " Cleanup complete."
echo ""
echo " Please verify in the AWS Console that all resources"
echo " prefixed with 'kata-XXX-' have been removed."
echo ""
echo " ⚠️  Any remaining resources may continue to incur"
echo " costs. You are responsible for all charges in your"
echo " AWS account."
echo "=================================================="
echo ""