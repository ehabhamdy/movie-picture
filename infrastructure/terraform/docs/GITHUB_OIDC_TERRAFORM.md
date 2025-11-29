# GitHub OIDC Setup with Terraform

This guide explains how to set up GitHub Actions OIDC authentication with AWS using Terraform instead of manual AWS CLI commands.

## What's Included

The Terraform configuration now includes:

1. **OIDC Provider** - Establishes trust between AWS and GitHub Actions
2. **IAM Role** - Role that GitHub Actions will assume
3. **IAM Policy** - Permissions for accessing ECR and EKS
4. **Policy Attachment** - Links the policy to the role

## Prerequisites

- Terraform >= 1.3.9 installed
- AWS CLI configured with admin permissions
- Access to your GitHub repository

## Setup Steps

### Step 1: Configure Variables

1. Copy the example tfvars file:
   ```bash
   cd infrastructure/terraform
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your values:
   ```hcl
   github_org  = "your-github-username-or-org"
   github_repo = "your-repository-name"
   ```

   Example:
   ```hcl
   github_org  = "john-doe"
   github_repo = "movie-picture"
   ```

### Step 2: Initialize and Apply Terraform

1. Initialize Terraform (if not already done):
   ```bash
   terraform init
   ```

2. Review the planned changes:
   ```bash
   terraform plan
   ```

3. Apply the configuration:
   ```bash
   terraform apply
   ```

4. Note the outputs - you'll need these for GitHub secrets:
   ```bash
   terraform output github_actions_role_arn
   terraform output aws_region
   terraform output cluster_name
   terraform output frontend_ecr
   terraform output backend_ecr
   ```

### Step 3: Configure GitHub Secrets

Add the following secrets to your GitHub repository:

1. Navigate to your repository on GitHub
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Add the following secrets:

   | Secret Name | Value | Example |
   |-------------|-------|---------|
   | `AWS_ROLE_ARN` | Output from `github_actions_role_arn` | `arn:aws:iam::123456789012:role/GitHubActionsRole` |
   | `AWS_REGION` | `us-east-1` | `us-east-1` |
   | `EKS_CLUSTER_NAME` | Output from `cluster_name` | `cluster` |
   | `ECR_BACKEND_REPO` | `movie-picture/backend` | `movie-picture/backend` |
   | `ECR_FRONTEND_REPO` | `movie-picture/frontend` | `movie-picture/frontend` |

### Step 4: Update GitHub Actions Workflow

Ensure your workflow file has the correct permissions:

```yaml
name: Deploy to EKS

on:
  push:
    branches: [main]

permissions:
  id-token: write   # Required for OIDC
  contents: read    # Required to checkout code

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ secrets.AWS_REGION }}

      # Your deployment steps here...
```

## What Was Created

### 1. OIDC Provider
- **Resource:** `aws_iam_openid_connect_provider.github_actions`
- **URL:** `https://token.actions.githubusercontent.com`
- **Purpose:** Establishes trust between GitHub and AWS

### 2. IAM Role
- **Resource:** `aws_iam_role.github_actions`
- **Name:** `GitHubActionsRole`
- **Purpose:** Role that GitHub Actions assumes to access AWS resources

### 3. IAM Policy
- **Resource:** `aws_iam_policy.github_actions`
- **Name:** `GitHubActionsPolicy`
- **Permissions:**
  - ECR: Push/pull container images
  - EKS: Describe cluster and deploy applications
  - CloudWatch: Write logs

## Verify Setup

After applying Terraform and configuring GitHub secrets, verify the setup:

1. Check if the OIDC provider exists:
   ```bash
   aws iam get-openid-connect-provider \
     --open-id-connect-provider-arn $(terraform output -raw github_oidc_provider_arn)
   ```

2. Check if the role exists:
   ```bash
   aws iam get-role --role-name GitHubActionsRole
   ```

3. Trigger a GitHub Actions workflow and verify it can authenticate with AWS

## Updating Configuration

### Change GitHub Repository

To change the GitHub repository that can assume the role:

1. Update `terraform.tfvars`:
   ```hcl
   github_org  = "new-org"
   github_repo = "new-repo"
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

### Update Permissions

To modify permissions, edit the `aws_iam_policy.github_actions` resource in `main.tf` and run:

```bash
terraform apply
```

## Troubleshooting

### Issue: "No OIDC provider found"
**Solution:** Ensure `terraform apply` completed successfully and check the provider ARN:
```bash
terraform output github_oidc_provider_arn
```

### Issue: "Not authorized to perform sts:AssumeRoleWithWebIdentity"
**Solution:** Verify that:
1. The `AWS_ROLE_ARN` secret in GitHub matches the Terraform output
2. The `github_org` and `github_repo` variables in `terraform.tfvars` match your actual repository
3. Your workflow has `permissions.id-token: write`

### Issue: "Access denied" when pushing to ECR
**Solution:** Check that the IAM policy includes ECR permissions and the role is properly attached:
```bash
aws iam list-attached-role-policies --role-name GitHubActionsRole
```

## Migration from Manual Setup

If you previously set up OIDC manually using AWS CLI:

1. **Import existing resources** (optional):
   ```bash
   # Import OIDC provider
   terraform import aws_iam_openid_connect_provider.github_actions \
     arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com

   # Import role
   terraform import aws_iam_role.github_actions GitHubActionsRole

   # Import policy
   terraform import aws_iam_policy.github_actions \
     arn:aws:iam::ACCOUNT_ID:policy/GitHubActionsPolicy
   ```

2. **Or delete and recreate**:
   ```bash
   # Delete existing resources
   aws iam detach-role-policy --role-name GitHubActionsRole \
     --policy-arn arn:aws:iam::ACCOUNT_ID:policy/GitHubActionsPolicy
   aws iam delete-role --role-name GitHubActionsRole
   aws iam delete-policy --policy-arn arn:aws:iam::ACCOUNT_ID:policy/GitHubActionsPolicy
   aws iam delete-open-id-connect-provider \
     --open-id-connect-provider-arn arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com

   # Then run terraform apply
   terraform apply
   ```

## Additional Resources

- [GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS IAM OIDC Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Security Notes

1. **Least Privilege**: The policy grants broad permissions (`Resource = "*"`). Consider restricting to specific resources in production.
2. **Repository Scope**: The trust policy uses `repo:${github_org}/${github_repo}:*` which allows any branch/tag. Consider restricting to specific branches:
   ```hcl
   "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
   ```
3. **Thumbprint**: The OIDC thumbprint `6938fd4d98bab03faadb97b34396831e3780aea1` is current as of 2024. AWS may update this periodically.

