# GitHub OIDC Setup

This document will guide you through the process of setting up GitHub OIDC authentication with AWS.

## Prerequisites

- AWS CLI installed and configured with admin permissions
- Access to your GitHub repository settings

## Step 1: AWS Setup


- [ ] **Step 1.1:** Get your AWS Account ID
  ```bash
  aws sts get-caller-identity --query Account --output text
  ```

- [ ] **Step 1.2:** Create OIDC Provider
  ```bash
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
  ```
  **Note:** The thumbprint may change over time. You can get the current one using the following command:
  ```bash
  echo | openssl s_client -servername token.actions.githubusercontent.com \
    -connect token.actions.githubusercontent.com:443 2>/dev/null | \
    openssl x509 -fingerprint -sha1 -noout | \
    cut -d'=' -f2 | tr -d ':'
  ```

  **On AWS Console:**
  ![OIDC Provider](./images/oidc-provider.png)

- [ ] **Step 1.3:** Edit trust policy file and permissions policy file with your account ID, GitHub org/username, and repository name
  Replace:
  - `YOUR_AWS_ACCOUNT_ID` → Your account ID
  - `YOUR_GITHUB_ORG` → Your GitHub org/username
  - `YOUR_REPO_NAME` → Your repository name

- [ ] **Step 1.4:** Create IAM Role
  ```bash 
  aws iam create-role \
    --role-name GitHubActionsRole \
    --assume-role-policy-document file://infrastructure/templates/devops/github-oidc-trust-policy.json
  ```
- [ ] **Step 1.5:** Create IAM Policy
  ```bash
  aws iam create-policy \
    --policy-name GitHubActionsPolicy \
    --policy-document file://infrastructure/templates/devops/github-oidc-permissions-policy.json
  ```

- [ ] **Step 1.6:** Attach policy to role
  ```bash
  aws iam attach-role-policy \
    --role-name GitHubActionsRole \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/GitHubActionsPolicy
  ```

- [ ] **Step 1.7:** Get the Role ARN 
  ```bash
  aws iam get-role --role-name GitHubActionsRole --query 'Role.Arn' --output text
  ```

**Save this Role ARN!** You'll need it for GitHub secrets.

## Step 2: GitHub Configuration

- [ ] **Step 2.1:** Open your GitHub repository in browser
  ```
  https://github.com/YOUR_ORG/YOUR_REPO
  ```

- [ ] **Step 2.2:** add the following secrets to your repository:
  - AWS_ROLE_ARN: (paste the Role ARN from Step 1.7)
  - AWS_REGION: (your AWS region)
  - EKS_CLUSTER_NAME: (your EKS cluster name)
  - ECR_BACKEND_REPO: (your backend ECR repository name)
  - ECR_FRONTEND_REPO: (your frontend ECR repository name)

- [ ] **Step 2.3:** add the following permission to your workflow file:
  ```yaml
  permissions:
    id-token: write # Required for OIDC
    contents: read # Required to checkout code
  ```


# References:
- [Use IAM roles to connect GitHub Actions to actions in AWS](https://aws.amazon.com/blogs/security/use-iam-roles-to-connect-github-actions-to-actions-in-aws/)
- [GitHub OIDC Setup](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-cloud-providers)
- [AWS OIDC Setup](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
