# GitHub OIDC Setup: Manual vs Terraform Comparison

## Summary of Changes

The GitHub OIDC setup has been migrated from manual AWS CLI commands to Terraform infrastructure as code.

## What Was Added to Terraform

### Files Created/Modified:

1. **`infrastructure/terraform/variables.tf`**
   - Added `github_org` variable
   - Added `github_repo` variable

2. **`infrastructure/terraform/main.tf`**
   - Added OIDC Provider resource
   - Added IAM Role for GitHub Actions
   - Added IAM Policy for GitHub Actions
   - Added Policy attachment

3. **`infrastructure/terraform/outputs.tf`**
   - Added `github_actions_role_arn` output
   - Added `github_oidc_provider_arn` output
   - Added `aws_account_id` output
   - Added `aws_region` output

4. **`infrastructure/terraform/terraform.tfvars.example`**
   - Template for user configuration

5. **`infrastructure/terraform/GITHUB_OIDC_TERRAFORM.md`**
   - Comprehensive setup guide

6. **`infrastructure/terraform/GITHUB_SECRETS_REFERENCE.md`**
   - Quick reference for GitHub secrets

## Comparison

### Manual Setup (Old Method)

```bash
# Step 1: Create OIDC Provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Step 2: Edit JSON files manually
# Replace YOUR_AWS_ACCOUNT_ID, YOUR_GITHUB_ORG, YOUR_REPO_NAME

# Step 3: Create IAM Role
aws iam create-role \
  --role-name GitHubActionsRole \
  --assume-role-policy-document file://infrastructure/templates/github-oidc-trust-policy.json

# Step 4: Create IAM Policy
aws iam create-policy \
  --policy-name GitHubActionsPolicy \
  --policy-document file://infrastructure/templates/github-actions-permissions-policy.json

# Step 5: Attach Policy
aws iam attach-role-policy \
  --role-name GitHubActionsRole \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/GitHubActionsPolicy

# Step 6: Get Role ARN
aws iam get-role --role-name GitHubActionsRole --query 'Role.Arn' --output text
```

**Drawbacks:**
- ❌ Manual steps prone to errors
- ❌ Need to manually edit JSON files
- ❌ Hard to track changes
- ❌ Difficult to recreate or share
- ❌ No state management
- ❌ Manual cleanup required

### Terraform Setup (New Method)

```bash
# Step 1: Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your github_org and github_repo

# Step 2: Apply Terraform
terraform init
terraform apply

# Step 3: Get outputs for GitHub secrets
terraform output github_actions_role_arn
```

**Benefits:**
- ✅ Declarative infrastructure as code
- ✅ Automatic variable substitution
- ✅ Version control friendly
- ✅ Easy to recreate and share
- ✅ State management built-in
- ✅ Easy cleanup with `terraform destroy`
- ✅ Idempotent operations
- ✅ Dependency management
- ✅ Better documentation

## Migration Path

### If You Already Have Manual Setup

**Option 1: Import Existing Resources**
```bash
# Get your account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Import OIDC provider
terraform import aws_iam_openid_connect_provider.github_actions \
  arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com

# Import role
terraform import aws_iam_role.github_actions GitHubActionsRole

# Import policy
terraform import aws_iam_policy.github_actions \
  arn:aws:iam::${ACCOUNT_ID}:policy/GitHubActionsPolicy

# Import attachment
terraform import aws_iam_role_policy_attachment.github_actions \
  GitHubActionsRole/arn:aws:iam::${ACCOUNT_ID}:policy/GitHubActionsPolicy
```

**Option 2: Delete and Recreate (Recommended for Clean Start)**
```bash
# Delete existing resources
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws iam detach-role-policy \
  --role-name GitHubActionsRole \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/GitHubActionsPolicy

aws iam delete-role --role-name GitHubActionsRole

aws iam delete-policy \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/GitHubActionsPolicy

aws iam delete-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com

# Then create with Terraform
cd infrastructure/terraform
terraform apply
```

### If Starting Fresh

Just follow the Terraform setup guide in `GITHUB_OIDC_TERRAFORM.md`

## Resources Created

| Resource Type | Name | Purpose |
|--------------|------|---------|
| OIDC Provider | `token.actions.githubusercontent.com` | Trust relationship with GitHub |
| IAM Role | `GitHubActionsRole` | Role assumed by GitHub Actions |
| IAM Policy | `GitHubActionsPolicy` | Permissions for ECR, EKS, CloudWatch |
| Role Policy Attachment | N/A | Links policy to role |

## Terraform Resources

```hcl
# In main.tf:
resource "aws_iam_openid_connect_provider" "github_actions"
resource "aws_iam_role" "github_actions"
resource "aws_iam_policy" "github_actions"
resource "aws_iam_role_policy_attachment" "github_actions"

# In variables.tf:
variable "github_org"
variable "github_repo"

# In outputs.tf:
output "github_actions_role_arn"
output "github_oidc_provider_arn"
output "aws_account_id"
output "aws_region"
```

## Next Steps

1. **Configure your repository:**
   ```bash
   cd infrastructure/terraform
   cp terraform.tfvars.example terraform.tfvars
   vim terraform.tfvars  # Edit with your values
   ```

2. **Apply Terraform:**
   ```bash
   terraform init
   terraform apply
   ```

3. **Set GitHub Secrets:**
   Follow the guide in `GITHUB_SECRETS_REFERENCE.md`

4. **Test your workflow:**
   Push a commit and verify GitHub Actions can authenticate

## Rollback

If you need to remove the OIDC setup:

```bash
cd infrastructure/terraform
terraform destroy -target=aws_iam_role_policy_attachment.github_actions
terraform destroy -target=aws_iam_policy.github_actions
terraform destroy -target=aws_iam_role.github_actions
terraform destroy -target=aws_iam_openid_connect_provider.github_actions
```

Or destroy everything:
```bash
terraform destroy
```

