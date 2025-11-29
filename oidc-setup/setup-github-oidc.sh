#!/bin/bash
# Script to setup GitHub OIDC provider and IAM role in AWS
# This automates the manual steps described in docs/GITHUB_OIDC_SETUP.md

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== GitHub OIDC Provider Setup for AWS ===${NC}\n"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}ERROR: AWS CLI is not installed${NC}"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: Unable to get AWS Account ID${NC}"
    echo "Please configure AWS CLI credentials with: aws configure"
    exit 1
fi

echo -e "${GREEN}✓ AWS Account ID: ${AWS_ACCOUNT_ID}${NC}\n"

# Prompt for GitHub repository information
echo "Please provide your GitHub repository information:"
read -p "GitHub Organization/Username: " GITHUB_ORG
read -p "Repository Name (e.g., movie-picture): " REPO_NAME
read -p "IAM Role Name [GitHubActionsRole]: " ROLE_NAME
ROLE_NAME=${ROLE_NAME:-GitHubActionsRole}

echo -e "\n${YELLOW}Configuration:${NC}"
echo "  AWS Account: $AWS_ACCOUNT_ID"
echo "  GitHub Repo: $GITHUB_ORG/$REPO_NAME"
echo "  IAM Role: $ROLE_NAME"
echo ""

read -p "Continue with this configuration? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled"
    exit 1
fi

echo -e "\n${GREEN}Step 1: Creating OIDC Provider${NC}"

# Check if OIDC provider already exists
OIDC_PROVIDER_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" &>/dev/null; then
    echo -e "${YELLOW}⚠ OIDC provider already exists${NC}"
    echo "  ARN: $OIDC_PROVIDER_ARN"
else
    # Get the thumbprint
    THUMBPRINT="6938fd4d98bab03faadb97b34396831e3780aea1"
    
    # Create OIDC provider
    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list "$THUMBPRINT" \
        --output json

    echo -e "${GREEN}✓ OIDC provider created${NC}"
    echo "  ARN: $OIDC_PROVIDER_ARN"
fi

echo -e "\n${GREEN}Step 2: Creating IAM Role with Trust Policy${NC}"

# Create trust policy
TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${REPO_NAME}:*"
        }
      }
    }
  ]
}
EOF
)

# Check if role already exists
if aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
    echo -e "${YELLOW}⚠ Role already exists, updating trust policy${NC}"
    
    # Update trust policy
    aws iam update-assume-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-document "$TRUST_POLICY"
    
    echo -e "${GREEN}✓ Trust policy updated${NC}"
else
    # Create the role
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document "$TRUST_POLICY" \
        --description "Role for GitHub Actions OIDC authentication" \
        --output json

    echo -e "${GREEN}✓ IAM Role created${NC}"
fi

ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
echo "  ARN: $ROLE_ARN"

echo -e "\n${GREEN}Step 3: Attaching Permissions to IAM Role${NC}"

# Create custom policy for GitHub Actions
POLICY_NAME="GitHubActionsPolicy"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"

PERMISSIONS_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRPermissions",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories",
        "ecr:ListImages"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EKSPermissions",
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:DescribeNodegroup",
        "eks:ListNodegroups"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": "arn:aws:logs:*:${AWS_ACCOUNT_ID}:*"
    }
  ]
}
EOF
)

# Check if policy exists
if aws iam get-policy --policy-arn "$POLICY_ARN" &>/dev/null; then
    echo -e "${YELLOW}⚠ Policy already exists${NC}"
    
    # Create a new version
    POLICY_VERSION=$(aws iam create-policy-version \
        --policy-arn "$POLICY_ARN" \
        --policy-document "$PERMISSIONS_POLICY" \
        --set-as-default \
        --query 'PolicyVersion.VersionId' \
        --output text)
    
    echo -e "${GREEN}✓ Policy updated (version: $POLICY_VERSION)${NC}"
else
    # Create policy
    aws iam create-policy \
        --policy-name "$POLICY_NAME" \
        --policy-document "$PERMISSIONS_POLICY" \
        --description "Permissions for GitHub Actions workflows" \
        --output json

    echo -e "${GREEN}✓ Policy created${NC}"
fi

echo "  ARN: $POLICY_ARN"

# Attach policy to role
if aws iam list-attached-role-policies --role-name "$ROLE_NAME" | grep -q "$POLICY_NAME"; then
    echo -e "${YELLOW}⚠ Policy already attached to role${NC}"
else
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "$POLICY_ARN"
    
    echo -e "${GREEN}✓ Policy attached to role${NC}"
fi

echo -e "\n${GREEN}=== Setup Complete! ===${NC}\n"

echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Add the following secret to your GitHub repository:"
echo "   Name: AWS_ROLE_ARN"
echo "   Value: ${ROLE_ARN}"
echo ""
echo "2. Update your GitHub Actions workflow file to use OIDC:"
echo "   See docs/GITHUB_OIDC_SETUP.md for examples"
echo ""
echo "3. Remove old secrets (if they exist):"
echo "   - AWS_ACCESS_KEY_ID"
echo "   - AWS_SECRET_ACCESS_KEY"
echo ""
echo -e "${GREEN}4. Test your workflow!${NC}"
echo ""

echo -e "${YELLOW}Important Information (save this):${NC}"
echo "  OIDC Provider ARN: ${OIDC_PROVIDER_ARN}"
echo "  IAM Role ARN:      ${ROLE_ARN}"
echo "  IAM Policy ARN:    ${POLICY_ARN}"
echo "  GitHub Repo:       ${GITHUB_ORG}/${REPO_NAME}"
echo ""

# Save configuration to file
CONFIG_FILE="github-oidc-config.txt"
cat > "$CONFIG_FILE" <<EOF
GitHub OIDC Configuration
Generated: $(date)

AWS Account ID: ${AWS_ACCOUNT_ID}
GitHub Repository: ${GITHUB_ORG}/${REPO_NAME}

OIDC Provider ARN: ${OIDC_PROVIDER_ARN}
IAM Role ARN: ${ROLE_ARN}
IAM Policy ARN: ${POLICY_ARN}

GitHub Secret to Add:
  Name: AWS_ROLE_ARN
  Value: ${ROLE_ARN}
EOF

echo -e "${GREEN}Configuration saved to: $CONFIG_FILE${NC}"

