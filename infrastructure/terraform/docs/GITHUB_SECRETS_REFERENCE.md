# Quick Reference: GitHub Secrets Setup

After running `terraform apply`, use these commands to get the values for your GitHub secrets:

## Get All Values at Once

```bash
cd infrastructure/terraform

echo "=== GitHub Secrets Configuration ==="
echo ""
echo "AWS_ROLE_ARN:"
terraform output -raw github_actions_role_arn
echo ""
echo ""
echo "AWS_REGION:"
terraform output -raw aws_region
echo ""
echo ""
echo "EKS_CLUSTER_NAME:"
terraform output -raw cluster_name
echo ""
echo ""
echo "ECR_BACKEND_REPO:"
echo "movie-picture/backend"
echo ""
echo "ECR_FRONTEND_REPO:"
echo "movie-picture/frontend"
echo ""
```

## Individual Commands

```bash
# AWS_ROLE_ARN
terraform output -raw github_actions_role_arn

# AWS_REGION
terraform output -raw aws_region

# EKS_CLUSTER_NAME
terraform output -raw cluster_name

# ECR_BACKEND_REPO (hardcoded)
echo "movie-picture/backend"

# ECR_FRONTEND_REPO (hardcoded)
echo "movie-picture/frontend"

# AWS_ACCOUNT_ID (if needed)
terraform output -raw aws_account_id
```

## Adding Secrets to GitHub

### Via GitHub Web UI:
1. Go to: `https://github.com/YOUR_ORG/YOUR_REPO/settings/secrets/actions`
2. Click "New repository secret"
3. Add each secret with the values from above

### Via GitHub CLI:
```bash
# Set your repo
export GITHUB_REPO="your-org/your-repo"

# Add secrets
gh secret set AWS_ROLE_ARN -b "$(cd infrastructure/terraform && terraform output -raw github_actions_role_arn)"
gh secret set AWS_REGION -b "us-east-1"
gh secret set EKS_CLUSTER_NAME -b "$(cd infrastructure/terraform && terraform output -raw cluster_name)"
gh secret set ECR_BACKEND_REPO -b "movie-picture/backend"
gh secret set ECR_FRONTEND_REPO -b "movie-picture/frontend"
```

## Verify Secrets

```bash
# List all secrets (names only, not values)
gh secret list
```

Expected output:
```
AWS_ROLE_ARN         Updated YYYY-MM-DD
AWS_REGION          Updated YYYY-MM-DD
EKS_CLUSTER_NAME    Updated YYYY-MM-DD
ECR_BACKEND_REPO    Updated YYYY-MM-DD
ECR_FRONTEND_REPO   Updated YYYY-MM-DD
```

