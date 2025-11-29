#!/bin/bash
# Script to verify GitHub OIDC setup in AWS
# This script checks if all components are correctly configured

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== GitHub OIDC Setup Verification ===${NC}\n"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI is installed${NC}"

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}✗ Unable to get AWS Account ID${NC}"
    exit 1
fi
echo -e "${GREEN}✓ AWS Account ID: ${AWS_ACCOUNT_ID}${NC}\n"

# Prompt for role name
read -p "Enter IAM Role Name [GitHubActionsRole]: " ROLE_NAME
ROLE_NAME=${ROLE_NAME:-GitHubActionsRole}

echo -e "\n${BLUE}Checking OIDC Provider...${NC}"

# Check OIDC Provider
OIDC_PROVIDER_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" &>/dev/null; then
    echo -e "${GREEN}✓ OIDC provider exists${NC}"
    echo "  ARN: $OIDC_PROVIDER_ARN"
    
    # Get provider details
    PROVIDER_DETAILS=$(aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN")
    CLIENT_ID=$(echo "$PROVIDER_DETAILS" | jq -r '.ClientIDList[]')
    THUMBPRINT=$(echo "$PROVIDER_DETAILS" | jq -r '.ThumbprintList[]')
    
    echo "  Client IDs: $CLIENT_ID"
    echo "  Thumbprint: $THUMBPRINT"
    
    if [ "$CLIENT_ID" = "sts.amazonaws.com" ]; then
        echo -e "${GREEN}  ✓ Client ID is correct${NC}"
    else
        echo -e "${YELLOW}  ⚠ Client ID should be 'sts.amazonaws.com'${NC}"
    fi
else
    echo -e "${RED}✗ OIDC provider does not exist${NC}"
    echo "  Run: ./infrastructure/setup-github-oidc.sh to create it"
    exit 1
fi

echo -e "\n${BLUE}Checking IAM Role...${NC}"

# Check IAM Role
if aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
    echo -e "${GREEN}✓ IAM Role exists: $ROLE_NAME${NC}"
    
    ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
    echo "  ARN: $ROLE_ARN"
    
    # Get trust policy
    echo -e "\n${BLUE}Checking Trust Policy...${NC}"
    TRUST_POLICY=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.AssumeRolePolicyDocument' --output json)
    
    # Check if trust policy includes OIDC provider
    if echo "$TRUST_POLICY" | jq -e '.Statement[] | select(.Principal.Federated | contains("token.actions.githubusercontent.com"))' &>/dev/null; then
        echo -e "${GREEN}✓ Trust policy includes GitHub OIDC provider${NC}"
        
        # Extract and display the sub condition
        SUB_CONDITION=$(echo "$TRUST_POLICY" | jq -r '.Statement[].Condition.StringLike."token.actions.githubusercontent.com:sub" // .Statement[].Condition.StringEquals."token.actions.githubusercontent.com:sub"')
        echo "  Allowed repositories: $SUB_CONDITION"
        
        # Check audience
        AUD_CONDITION=$(echo "$TRUST_POLICY" | jq -r '.Statement[].Condition.StringEquals."token.actions.githubusercontent.com:aud"')
        if [ "$AUD_CONDITION" = "sts.amazonaws.com" ]; then
            echo -e "${GREEN}  ✓ Audience is correct${NC}"
        else
            echo -e "${YELLOW}  ⚠ Audience should be 'sts.amazonaws.com', found: $AUD_CONDITION${NC}"
        fi
    else
        echo -e "${RED}✗ Trust policy does not include GitHub OIDC provider${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ IAM Role does not exist: $ROLE_NAME${NC}"
    echo "  Run: ./infrastructure/setup-github-oidc.sh to create it"
    exit 1
fi

echo -e "\n${BLUE}Checking IAM Policies...${NC}"

# List attached policies
ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query 'AttachedPolicies[*].[PolicyName,PolicyArn]' --output text)

if [ -z "$ATTACHED_POLICIES" ]; then
    echo -e "${YELLOW}⚠ No policies attached to role${NC}"
else
    echo -e "${GREEN}✓ Attached policies:${NC}"
    echo "$ATTACHED_POLICIES" | while IFS=$'\t' read -r name arn; do
        echo "  - $name"
        echo "    ARN: $arn"
    done
fi

echo -e "\n${BLUE}Checking Required Permissions...${NC}"

# Check for ECR permissions
ECR_CHECK=false
EKS_CHECK=false

echo "$ATTACHED_POLICIES" | while IFS=$'\t' read -r name arn; do
    POLICY_VERSION=$(aws iam get-policy --policy-arn "$arn" --query 'Policy.DefaultVersionId' --output text 2>/dev/null || echo "v1")
    POLICY_DOCUMENT=$(aws iam get-policy-version --policy-arn "$arn" --version-id "$POLICY_VERSION" --query 'PolicyVersion.Document' --output json 2>/dev/null || echo "{}")
    
    # Check for ECR permissions
    if echo "$POLICY_DOCUMENT" | jq -e '.Statement[] | select(.Action | if type == "string" then . else .[] end | contains("ecr:"))' &>/dev/null; then
        echo -e "${GREEN}✓ Found ECR permissions in policy: $name${NC}"
        ECR_CHECK=true
    fi
    
    # Check for EKS permissions
    if echo "$POLICY_DOCUMENT" | jq -e '.Statement[] | select(.Action | if type == "string" then . else .[] end | contains("eks:"))' &>/dev/null; then
        echo -e "${GREEN}✓ Found EKS permissions in policy: $name${NC}"
        EKS_CHECK=true
    fi
done

if [ "$ECR_CHECK" = false ]; then
    echo -e "${YELLOW}⚠ No ECR permissions found (required for pushing Docker images)${NC}"
fi

if [ "$EKS_CHECK" = false ]; then
    echo -e "${YELLOW}⚠ No EKS permissions found (required for deploying to Kubernetes)${NC}"
fi

echo -e "\n${BLUE}=== Summary ===${NC}\n"

echo -e "${GREEN}Configuration Details:${NC}"
echo "  AWS Account ID: $AWS_ACCOUNT_ID"
echo "  OIDC Provider ARN: $OIDC_PROVIDER_ARN"
echo "  IAM Role ARN: $ROLE_ARN"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Add the following secret to your GitHub repository:"
echo "   Name: AWS_ROLE_ARN"
echo "   Value: $ROLE_ARN"
echo ""
echo "2. Ensure you have these other secrets configured:"
echo "   - AWS_REGION (e.g., us-east-1)"
echo "   - EKS_CLUSTER_NAME"
echo "   - ECR_BACKEND_REPO"
echo "   - ECR_FRONTEND_REPO"
echo ""
echo "3. Remove old secrets (if they exist):"
echo "   - AWS_ACCESS_KEY_ID"
echo "   - AWS_SECRET_ACCESS_KEY"
echo ""
echo "4. Test your GitHub Actions workflow!"
echo ""

echo -e "${GREEN}✓ Verification complete!${NC}"

