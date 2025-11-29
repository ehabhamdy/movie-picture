# GitHub OIDC Setup - Quick Reference Guide

This is a quick reference for setting up and using GitHub OIDC authentication with AWS.

## 🚀 Quick Setup (5 Steps)

### 1. Run the Setup Script

```bash
cd infrastructure
./setup-github-oidc.sh
```

This script will:
- Create the OIDC provider in AWS
- Create an IAM role with proper trust policy
- Attach necessary permissions for ECR and EKS
- Output the role ARN you'll need

### 2. Add GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add/Update these secrets:

| Secret Name | Description | Example |
|------------|-------------|---------|
| `AWS_ROLE_ARN` | IAM Role ARN from setup script | `arn:aws:iam::123456789012:role/GitHubActionsRole` |
| `AWS_REGION` | Your AWS region | `us-east-1` |
| `EKS_CLUSTER_NAME` | Your EKS cluster name | `movie-picture-cluster` |
| `ECR_BACKEND_REPO` | Backend ECR repository name | `movie-picture-backend` |
| `ECR_FRONTEND_REPO` | Frontend ECR repository name | `movie-picture-frontend` |

### 3. Remove Old Secrets

❌ Delete these (no longer needed):
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### 4. Verify Setup

```bash
cd infrastructure
./verify-github-oidc.sh
```

### 5. Test Your Workflow

Run your GitHub Actions workflow and verify it authenticates successfully.

---

## 📝 What Changed in Your Workflows

### Before (Using Access Keys) ❌
```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v2
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: ${{ secrets.AWS_REGION }}
```

### After (Using OIDC) ✅
```yaml
permissions:
  id-token: write   # Required for OIDC
  contents: read

jobs:
  build:
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          role-session-name: GitHubActions-${{ github.run_id }}
          aws-region: ${{ secrets.AWS_REGION }}
```

---

## 🔧 Manual Setup (If Not Using Script)

<details>
<summary>Click to expand manual setup instructions</summary>

### Step 1: Create OIDC Provider

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### Step 2: Create Trust Policy File

Create `trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:*"
        }
      }
    }
  ]
}
```

Replace:
- `YOUR_ACCOUNT_ID` with your AWS account ID
- `YOUR_ORG/YOUR_REPO` with your GitHub org/repo

### Step 3: Create IAM Role

```bash
aws iam create-role \
  --role-name GitHubActionsRole \
  --assume-role-policy-document file://trust-policy.json
```

### Step 4: Create Permissions Policy

Create `permissions-policy.json`:

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
    }
  ]
}
```

### Step 5: Create and Attach Policy

```bash
# Create policy
aws iam create-policy \
  --policy-name GitHubActionsPolicy \
  --policy-document file://permissions-policy.json

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Attach policy to role
aws iam attach-role-policy \
  --role-name GitHubActionsRole \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/GitHubActionsPolicy
```

</details>

---

## 🔍 Troubleshooting

### Error: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Cause:** Trust policy mismatch

**Fix:**
1. Verify your repository name in the trust policy matches exactly (case-sensitive)
2. Check the OIDC provider ARN is correct
3. Ensure the audience is `sts.amazonaws.com`

```bash
# Check trust policy
aws iam get-role --role-name GitHubActionsRole \
  --query 'Role.AssumeRolePolicyDocument'
```

### Error: "No OIDC token available"

**Cause:** Missing permissions in workflow

**Fix:** Add to your workflow file:

```yaml
permissions:
  id-token: write
  contents: read
```

### Error: "Access Denied" when pushing to ECR or accessing EKS

**Cause:** IAM role lacks necessary permissions

**Fix:**
```bash
# List attached policies
aws iam list-attached-role-policies --role-name GitHubActionsRole

# Verify policy content
aws iam get-policy-version \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/GitHubActionsPolicy \
  --version-id v1
```

### Workflow runs but can't authenticate

**Cause:** Secret not configured correctly

**Fix:**
1. Verify `AWS_ROLE_ARN` secret exists in GitHub
2. Check it has the correct format: `arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME`
3. Ensure no trailing spaces or line breaks

---

## 🔐 Security Best Practices

### ✅ DO:
- Use specific repository/branch restrictions in trust policy
- Use unique role session names for auditing
- Regularly review CloudTrail logs
- Use least-privilege permissions
- Rotate OIDC thumbprints when they change

### ❌ DON'T:
- Use `*` for all repositories unless necessary
- Grant more permissions than needed
- Share the same role across unrelated projects
- Store access keys as fallback

---

## 📊 Trust Policy Options

### Allow any branch in repository
```json
"token.actions.githubusercontent.com:sub": "repo:myorg/myrepo:*"
```

### Allow only main branch
```json
"token.actions.githubusercontent.com:sub": "repo:myorg/myrepo:ref:refs/heads/main"
```

### Allow multiple specific branches
```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": [
    "repo:myorg/myrepo:ref:refs/heads/main",
    "repo:myorg/myrepo:ref:refs/heads/develop"
  ]
}
```

### Allow only from specific environment
```json
"token.actions.githubusercontent.com:sub": "repo:myorg/myrepo:environment:production"
```

### Allow pull requests
```json
"token.actions.githubusercontent.com:sub": "repo:myorg/myrepo:pull_request"
```

---

## 📚 Additional Resources

- [GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS IAM OIDC Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [configure-aws-credentials Action](https://github.com/aws-actions/configure-aws-credentials)
- [AWS Security Blog](https://aws.amazon.com/blogs/security/use-iam-roles-to-connect-github-actions-to-actions-in-aws/)

---

## 📁 Files Modified

The following workflow files have been updated to use OIDC:
- `.github/workflows/backend-cd.yaml`
- `.github/workflows/frontend-cd.yaml`

The CI workflows (`backend-ci.yaml`, `frontend-ci.yaml`) don't need AWS credentials since they only run tests locally.

---

## ✅ Verification Checklist

Before running your workflows:

- [ ] OIDC provider created in AWS
- [ ] IAM role created with GitHub trust policy
- [ ] Permissions policy attached to role
- [ ] `AWS_ROLE_ARN` secret added to GitHub
- [ ] Other required secrets configured
- [ ] Old access key secrets removed
- [ ] Workflow files updated with OIDC configuration
- [ ] Verification script runs successfully
- [ ] Test workflow completes successfully

---

## 🎉 Benefits You're Now Getting

✅ **No long-lived credentials** - tokens expire after workflow completes  
✅ **Better security** - credentials can't be leaked or stolen  
✅ **Automatic rotation** - new token for each workflow run  
✅ **Fine-grained access** - control by repo, branch, or environment  
✅ **Better auditing** - CloudTrail shows which workflow assumed the role  
✅ **Compliance-friendly** - meets security best practices  

---

For detailed setup instructions, see: [docs/GITHUB_OIDC_SETUP.md](./GITHUB_OIDC_SETUP.md)

