#!/bin/bash

# Script to clean up manually created GitHub OIDC resources
# Run this before terraform apply if you have manually created these resources

set -e

echo "🧹 Cleaning up manually created GitHub OIDC resources..."
echo ""

# Get AWS Account ID
echo "📋 Getting AWS Account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "   Account ID: ${ACCOUNT_ID}"
echo ""

# Step 1: Detach policy from role
echo "🔗 Detaching policy from role..."
aws iam detach-role-policy \
  --role-name GitHubActionsRole \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/GitHubActionsPolicy \
  2>/dev/null && echo "   ✅ Policy detached" || echo "   ⚠️  Policy not attached or already detached"
echo ""

# Step 2: Delete the role
echo "🗑️  Deleting IAM Role..."
aws iam delete-role \
  --role-name GitHubActionsRole \
  2>/dev/null && echo "   ✅ Role deleted" || echo "   ⚠️  Role not found or already deleted"
echo ""

# Step 3: Delete the policy
echo "🗑️  Deleting IAM Policy..."
aws iam delete-policy \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/GitHubActionsPolicy \
  2>/dev/null && echo "   ✅ Policy deleted" || echo "   ⚠️  Policy not found or already deleted"
echo ""

# Step 4: Delete OIDC Provider (optional, only if it exists)
echo "🗑️  Deleting OIDC Provider..."
aws iam delete-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com \
  2>/dev/null && echo "   ✅ OIDC Provider deleted" || echo "   ⚠️  OIDC Provider not found or already deleted"
echo ""

echo "✨ Cleanup complete! You can now run: terraform apply"

