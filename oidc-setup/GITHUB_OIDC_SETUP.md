# GitHub OIDC Provider Setup for AWS

This guide explains how to configure GitHub Actions to authenticate with AWS using OpenID Connect (OIDC) instead of long-lived access keys.

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Step 1: Create OIDC Provider in AWS](#step-1-create-oidc-provider-in-aws)
4. [Step 2: Create IAM Role with Trust Policy](#step-2-create-iam-role-with-trust-policy)
5. [Step 3: Attach Permissions to IAM Role](#step-3-attach-permissions-to-iam-role)
6. [Step 4: Update GitHub Actions Workflow](#step-4-update-github-actions-workflow)
7. [Step 5: Configure GitHub Secrets](#step-5-configure-github-secrets)
8. [Troubleshooting](#troubleshooting)

---

## Overview

**Benefits of OIDC over Access Keys:**
- ✅ No long-lived credentials stored in GitHub
- ✅ Automatic credential rotation
- ✅ Fine-grained access control per repository/branch
- ✅ Better security posture and audit trail
- ✅ Reduced risk of credential leakage

**How it works:**
1. GitHub generates a short-lived OIDC token for your workflow
2. The token contains claims about the repository, branch, and workflow
3. AWS validates the token and assumes an IAM role
4. Temporary credentials are issued for the workflow execution

---

## Prerequisites

- AWS CLI installed and configured with admin permissions
- Access to your GitHub repository settings
- AWS account with IAM permissions to create roles and OIDC providers

---

## Step 1: Create OIDC Provider in AWS

### Option A: Using AWS Console

1. Navigate to **IAM Console** → **Identity providers** → **Add provider**
2. Select **OpenID Connect**
3. Enter the following values:
   - **Provider URL:** `https://token.actions.githubusercontent.com`
   - **Audience:** `sts.amazonaws.com`
4. Click **Get thumbprint** (AWS will automatically fetch it)
5. Click **Add provider**

### Option B: Using AWS CLI

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

**Note:** The thumbprint may change over time. You can get the current one using:

```bash
# Get the thumbprint
echo | openssl s_client -servername token.actions.githubusercontent.com \
  -connect token.actions.githubusercontent.com:443 2>/dev/null | \
  openssl x509 -fingerprint -sha1 -noout | \
  cut -d'=' -f2 | tr -d ':'
```

### Verify Creation

```bash
aws iam list-open-id-connect-providers
```

You should see your provider with ARN: `arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com`

---

## Step 2: Create IAM Role with Trust Policy

### Understanding the Trust Policy

The trust policy determines which GitHub repositories and branches can assume the role.

**Key Claims in GitHub OIDC Token:**
- `sub` (subject): Identifies the specific workflow context
  - Format: `repo:OWNER/REPO:ref:refs/heads/BRANCH`
  - Examples:
    - `repo:myorg/myrepo:ref:refs/heads/main` (specific branch)
    - `repo:myorg/myrepo:*` (any branch in repo)
- `aud` (audience): `sts.amazonaws.com`
- `iss` (issuer): `https://token.actions.githubusercontent.com`

### Create the IAM Role

1. **Create a trust policy file** (`github-oidc-trust-policy.json`):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_AWS_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO_NAME:*"
        }
      }
    }
  ]
}
```

**Security Options for `sub` claim:**

```json
// Option 1: Allow any branch in the repository (less restrictive)
"token.actions.githubusercontent.com:sub": "repo:myorg/movie-picture:*"

// Option 2: Allow only main branch (more restrictive)
"token.actions.githubusercontent.com:sub": "repo:myorg/movie-picture:ref:refs/heads/main"

// Option 3: Allow main and specific branches
"StringLike": {
  "token.actions.githubusercontent.com:sub": [
    "repo:myorg/movie-picture:ref:refs/heads/main",
    "repo:myorg/movie-picture:ref:refs/heads/develop"
  ]
}

// Option 4: Allow only from specific environment
"token.actions.githubusercontent.com:sub": "repo:myorg/movie-picture:environment:production"

// Option 5: Allow pull requests
"token.actions.githubusercontent.com:sub": "repo:myorg/movie-picture:pull_request"
```

2. **Replace placeholders:**
   - `YOUR_AWS_ACCOUNT_ID`: Your 12-digit AWS account ID
   - `YOUR_GITHUB_ORG`: Your GitHub organization or username
   - `YOUR_REPO_NAME`: Your repository name (e.g., `movie-picture`)

3. **Create the role:**

```bash
# Get your AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create the role
aws iam create-role \
  --role-name GitHubActionsRole \
  --assume-role-policy-document file://github-oidc-trust-policy.json \
  --description "Role for GitHub Actions OIDC"
```

### For Multiple Repositories

If you want one role for multiple repos:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_AWS_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:myorg/movie-picture:*",
            "repo:myorg/another-repo:*"
          ]
        }
      }
    }
  ]
}
```

---

## Step 3: Attach Permissions to IAM Role

The IAM role needs permissions to perform AWS operations required by your workflows.

### Required Permissions for Your Workflows

Based on your backend-cd.yaml, you need:

1. **ECR permissions** (push Docker images)
2. **EKS permissions** (deploy to Kubernetes)
3. **Optional: CloudWatch Logs** (debugging)

### Option A: Using AWS Managed Policies (Quick Start)

```bash
# For ECR full access
aws iam attach-role-policy \
  --role-name GitHubActionsRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser

# For EKS access
aws iam attach-role-policy \
  --role-name GitHubActionsRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
```

### Option B: Custom Policy (Recommended - Least Privilege)

Create a custom policy file (`github-actions-permissions.json`):

```json
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
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EKSPermissions",
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

Create and attach the policy:

```bash
# Create the policy
aws iam create-policy \
  --policy-name GitHubActionsPolicy \
  --policy-document file://github-actions-permissions.json

# Get your account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Attach to role
aws iam attach-role-policy \
  --role-name GitHubActionsRole \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/GitHubActionsPolicy
```

### Verify Role Configuration

```bash
# Get role ARN
aws iam get-role --role-name GitHubActionsRole --query 'Role.Arn' --output text

# List attached policies
aws iam list-attached-role-policies --role-name GitHubActionsRole
```

**Save the Role ARN** - you'll need it in the next step!

---

## Step 4: Update GitHub Actions Workflow

Update your workflow to use OIDC authentication instead of access keys.

### Required Changes

1. **Add `id-token: write` permission** at the job level
2. **Replace access key authentication** with role-arn
3. **Remove references to AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY**

### Updated backend-cd.yaml Example

```yaml
name: Backend Continuous Deployment

on:
  workflow_dispatch:

# Optional: Set global permissions (can also be set per job)
permissions:
  id-token: write   # Required for OIDC
  contents: read    # Required to checkout code

jobs:
  build:
    name: Build and Push
    runs-on: ubuntu-latest
    needs: [lint, test]
    
    # Job-level permissions
    permissions:
      id-token: write
      contents: read

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::YOUR_ACCOUNT_ID:role/GitHubActionsRole
          role-session-name: GitHubActions-BackendDeploy
          aws-region: us-east-1  # Replace with your region

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, tag, and push image to Amazon ECR
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: your-backend-repo  # Replace with your repo name
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG ./backend
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG

  deploy:
    name: Deploy to Kubernetes
    runs-on: ubuntu-latest
    needs: build
    
    permissions:
      id-token: write
      contents: read

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::YOUR_ACCOUNT_ID:role/GitHubActionsRole
          role-session-name: GitHubActions-K8sDeploy
          aws-region: us-east-1

      - name: Update kubeconfig for EKS
        run: |
          aws eks update-kubeconfig --name your-cluster-name --region us-east-1

      - name: Deploy to EKS
        run: |
          cd backend/k8s
          kustomize edit set image backend=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          kustomize build | kubectl apply -f -
```

### Key Changes Explained

1. **`permissions: id-token: write`**
   - Allows the workflow to request OIDC tokens from GitHub
   - Can be set globally or per job

2. **`role-to-assume`**
   - ARN of the IAM role created in Step 3
   - Replaces `aws-access-key-id` and `aws-secret-access-key`

3. **`role-session-name`** (optional but recommended)
   - Helps identify sessions in CloudTrail logs
   - Makes auditing easier

4. **Version update**: Use `@v4` of `configure-aws-credentials` (supports OIDC)

---

## Step 5: Configure GitHub Secrets

You only need to store the IAM Role ARN now (not access keys!).

### Add GitHub Secrets

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**

**Required Secrets:**

| Secret Name | Value | Example |
|------------|-------|---------|
| `AWS_ROLE_ARN` | IAM Role ARN from Step 3 | `arn:aws:iam::123456789012:role/GitHubActionsRole` |
| `AWS_REGION` | Your AWS region | `us-east-1` |
| `EKS_CLUSTER_NAME` | Your EKS cluster name | `movie-picture-cluster` |
| `ECR_BACKEND_REPO` | Your ECR repository name | `movie-picture-backend` |
| `ECR_FRONTEND_REPO` | Your ECR repository name | `movie-picture-frontend` |

**Secrets to Remove:**
- ❌ `AWS_ACCESS_KEY_ID` (no longer needed!)
- ❌ `AWS_SECRET_ACCESS_KEY` (no longer needed!)

### Updated Workflow with Secrets

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    role-session-name: GitHubActions-${{ github.run_id }}
    aws-region: ${{ secrets.AWS_REGION }}
```

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Error: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Cause:** Trust policy mismatch

**Solution:** Verify the trust policy:
```bash
aws iam get-role --role-name GitHubActionsRole --query 'Role.AssumeRolePolicyDocument'
```

Check:
- Account ID is correct
- Repository name matches exactly (case-sensitive)
- OIDC provider ARN is correct

#### 2. Error: "No OIDC token available"

**Cause:** Missing `id-token: write` permission

**Solution:** Add to workflow:
```yaml
permissions:
  id-token: write
  contents: read
```

#### 3. Error: "Invalid identity token"

**Cause:** OIDC provider thumbprint mismatch

**Solution:** Update the thumbprint:
```bash
# Get current thumbprint
echo | openssl s_client -servername token.actions.githubusercontent.com \
  -connect token.actions.githubusercontent.com:443 2>/dev/null | \
  openssl x509 -fingerprint -sha1 -noout

# Update provider (or recreate it)
```

#### 4. Error: "User is not authorized to perform: eks:DescribeCluster"

**Cause:** IAM role lacks necessary permissions

**Solution:** Attach required permissions (see Step 3)

#### 5. Workflow succeeds but can't access resources

**Cause:** Role has assume permissions but not resource permissions

**Solution:** Verify attached policies:
```bash
aws iam list-attached-role-policies --role-name GitHubActionsRole
aws iam get-policy-version \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/PolicyName \
  --version-id v1
```

### Debugging Tips

1. **Check CloudTrail logs** for AssumeRoleWithWebIdentity events
2. **Use AWS CloudShell** to test role assumptions locally
3. **Enable debug logging** in GitHub Actions:
   ```yaml
   - name: Configure AWS credentials
     uses: aws-actions/configure-aws-credentials@v4
     with:
       role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
       aws-region: ${{ secrets.AWS_REGION }}
       debug: true  # Enable debug logging
   ```

4. **Verify OIDC token claims** by decoding the JWT (for debugging):
   ```bash
   # In your workflow, add a step to see token (remove after debugging!)
   - name: Debug OIDC token
     run: |
       curl -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
         "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=sts.amazonaws.com" | \
         jq -R 'split(".") | .[1] | @base64d | fromjson'
     env:
       ACTIONS_ID_TOKEN_REQUEST_TOKEN: ${{ env.ACTIONS_ID_TOKEN_REQUEST_TOKEN }}
       ACTIONS_ID_TOKEN_REQUEST_URL: ${{ env.ACTIONS_ID_TOKEN_REQUEST_URL }}
   ```

### Verify Setup

Test your configuration:

```bash
# 1. Verify OIDC provider exists
aws iam list-open-id-connect-providers

# 2. Verify role exists and get ARN
aws iam get-role --role-name GitHubActionsRole

# 3. Verify trust policy
aws iam get-role --role-name GitHubActionsRole \
  --query 'Role.AssumeRolePolicyDocument' \
  --output json

# 4. Verify attached policies
aws iam list-attached-role-policies --role-name GitHubActionsRole
```

---

## Additional Resources

- [GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS IAM OIDC Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [configure-aws-credentials Action](https://github.com/aws-actions/configure-aws-credentials)
- [AWS Security Blog: Use IAM roles with GitHub Actions](https://aws.amazon.com/blogs/security/use-iam-roles-to-connect-github-actions-to-actions-in-aws/)

---

## Summary Checklist

- [ ] Created OIDC provider in AWS
- [ ] Created IAM role with GitHub trust policy
- [ ] Attached necessary permissions to IAM role
- [ ] Updated GitHub Actions workflow with OIDC configuration
- [ ] Added `AWS_ROLE_ARN` secret to GitHub
- [ ] Removed old `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` secrets
- [ ] Tested workflow with OIDC authentication
- [ ] Verified CloudTrail logs show AssumeRoleWithWebIdentity events

🎉 You're now using secure, short-lived credentials with GitHub Actions!

