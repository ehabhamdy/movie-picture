# GitHub OIDC Setup - Step-by-Step Checklist

Use this checklist to set up OIDC authentication for your GitHub Actions workflows.

## Prerequisites

- [ ] AWS CLI installed and configured with admin permissions
- [ ] Access to your GitHub repository settings
- [ ] Terminal access to run setup scripts

---

## Part 1: AWS Setup (10 minutes)

### Option A: Automated Setup (Recommended)

- [ ] **Step 1.1:** Open terminal and navigate to project directory
  ```bash
  cd /Users/I575965/Documents/Code/Projects/aws/movie-picture
  ```

- [ ] **Step 1.2:** Run the setup script
  ```bash
  ./infrastructure/setup-github-oidc.sh
  ```

- [ ] **Step 1.3:** When prompted, enter:
  - GitHub Organization/Username: `____________`
  - Repository Name: `____________`
  - IAM Role Name: (press Enter for default or enter custom name)

- [ ] **Step 1.4:** Copy the Role ARN from the output
  ```
  Role ARN: arn:aws:iam::____________:role/____________
  ```
  **Save this!** You'll need it for GitHub secrets.

- [ ] **Step 1.5:** Verify the setup worked
  ```bash
  ./infrastructure/verify-github-oidc.sh
  ```
  - Should see green checkmarks ✓ for all checks

### Option B: Manual Setup (If script fails)

<details>
<summary>Click to expand manual setup steps</summary>

- [x] **Step 1.1:** Get your AWS Account ID
  ```bash
  aws sts get-caller-identity --query Account --output text
  ```
  Account ID: `____________`

- [x] **Step 1.2:** Create OIDC Provider
  ```bash
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
  ```

- [x] **Step 1.3:** Edit trust policy file
  ```bash
  nano infrastructure/templates/github-oidc-trust-policy.json
  ```
  Replace:
  - `YOUR_AWS_ACCOUNT_ID` → Your account ID
  - `YOUR_GITHUB_ORG` → Your GitHub org/username
  - `YOUR_REPO_NAME` → Your repository name

- [x] **Step 1.4:** Create IAM Role
  ```bash
  aws iam create-role \
    --role-name GitHubActionsRole \
    --assume-role-policy-document file://infrastructure/templates/devops/github-oidc-trust-policy.json
  ```

- [x] **Step 1.5:** Edit permissions policy file
  ```bash
  nano infrastructure/templates/github-actions-permissions-policy.json
  ```
  Replace `YOUR_AWS_ACCOUNT_ID` with your account ID

- [x] **Step 1.6:** Create IAM Policy
  ```bash
  aws iam create-policy \
    --policy-name GitHubActionsPolicy \
    --policy-document file://infrastructure/templates/github-actions-permissions-policy.json
  ```

- [x] **Step 1.7:** Attach policy to role
  ```bash
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  aws iam attach-role-policy \
    --role-name GitHubActionsRole \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/GitHubActionsPolicy
  ```

- [x] **Step 1.8:** Get the Role ARN
  ```bash
  aws iam get-role --role-name GitHubActionsRole --query 'Role.Arn' --output text
  ```
  Role ARN: `____________`

</details>

---

## Part 2: GitHub Configuration (5 minutes)

- [x] **Step 2.1:** Open your GitHub repository in browser
  ```
  https://github.com/YOUR_ORG/YOUR_REPO
  ```

- [x] **Step 2.2:** Navigate to repository settings
  - Click **Settings** tab
  - Click **Secrets and variables** in left sidebar
  - Click **Actions**

### Add New Secrets

- [x] **Step 2.3:** Add AWS_ROLE_ARN secret
  - Click **New repository secret**
  - Name: `AWS_ROLE_ARN`
  - Value: (paste the Role ARN from Step 1.4)
  - Click **Add secret**

- [x] **Step 2.4:** Verify/Update AWS_REGION secret
  - If exists, click to edit
  - If not exists, click **New repository secret**
  - Name: `AWS_REGION`
  - Value: `us-east-1` (or your region)
  - Click **Add secret** or **Update secret**

- [x] **Step 2.5:** Verify/Update EKS_CLUSTER_NAME secret
  - Name: `EKS_CLUSTER_NAME`
  - Value: (your EKS cluster name)
  
- [x] **Step 2.6:** Verify/Update ECR_BACKEND_REPO secret
  - Name: `ECR_BACKEND_REPO`
  - Value: (your backend ECR repository name)

- [x] **Step 2.7:** Verify/Update ECR_FRONTEND_REPO secret
  - Name: `ECR_FRONTEND_REPO`
  - Value: (your frontend ECR repository name)

### Remove Old Secrets

- [x] **Step 2.8:** Delete AWS_ACCESS_KEY_ID secret (if exists)
  - Find `AWS_ACCESS_KEY_ID` in the list
  - Click **Remove**
  - Confirm deletion

- [x] **Step 2.9:** Delete AWS_SECRET_ACCESS_KEY secret (if exists)
  - Find `AWS_SECRET_ACCESS_KEY` in the list
  - Click **Remove**
  - Confirm deletion

### Verify Secrets Configuration

- [x] **Step 2.10:** Confirm you have these secrets:
  - ✅ `AWS_ROLE_ARN`
  - ✅ `AWS_REGION`
  - ✅ `EKS_CLUSTER_NAME`
  - ✅ `ECR_BACKEND_REPO`
  - ✅ `ECR_FRONTEND_REPO`

- [x] **Step 2.11:** Confirm you DO NOT have these secrets:
  - ❌ `AWS_ACCESS_KEY_ID` (should be deleted)
  - ❌ `AWS_SECRET_ACCESS_KEY` (should be deleted)

---

## Part 3: Test the Setup (5 minutes)

### Test Backend Workflow

- [ ] **Step 3.1:** Navigate to Actions tab in GitHub
  ```
  https://github.com/YOUR_ORG/YOUR_REPO/actions
  ```

- [ ] **Step 3.2:** Select "Backend Continuous Deployment" workflow

- [ ] **Step 3.3:** Click **Run workflow** button

- [ ] **Step 3.4:** Select branch and click **Run workflow**

- [ ] **Step 3.5:** Wait for workflow to start and watch the logs

- [ ] **Step 3.6:** Verify "Configure AWS credentials" step succeeds
  - Should show: "AssumeRoleWithWebIdentity succeeded"
  - Should NOT show any "Access Denied" errors

- [ ] **Step 3.7:** Verify "Login to Amazon ECR" step succeeds
  - Should show: "Login succeeded"

### Test Frontend Workflow

- [ ] **Step 3.8:** Navigate to Actions tab

- [ ] **Step 3.9:** Select "Frontend Continuous Deployment" workflow

- [ ] **Step 3.10:** Click **Run workflow** and run it

- [ ] **Step 3.11:** Verify authentication succeeds (same as backend)

---

## Part 4: Verify in AWS (5 minutes)

### Check CloudTrail Logs

- [ ] **Step 4.1:** Open AWS CloudTrail console
  ```
  https://console.aws.amazon.com/cloudtrail
  ```

- [ ] **Step 4.2:** Go to **Event history**

- [ ] **Step 4.3:** Filter by:
  - Event name: `AssumeRoleWithWebIdentity`
  - Time range: Last 1 hour

- [ ] **Step 4.4:** Find event from your workflow run

- [ ] **Step 4.5:** Verify event details show:
  - User identity type: "WebIdentityUser"
  - Role session name includes your workflow run ID
  - Source IP matches GitHub Actions IP range

### Verify IAM Configuration

- [ ] **Step 4.6:** Open AWS IAM console
  ```
  https://console.aws.amazon.com/iam
  ```

- [ ] **Step 4.7:** Navigate to **Identity providers**

- [ ] **Step 4.8:** Verify OIDC provider exists
  - Provider: `token.actions.githubusercontent.com`
  - Audience: `sts.amazonaws.com`

- [ ] **Step 4.9:** Navigate to **Roles**

- [ ] **Step 4.10:** Find and click on your role (e.g., `GitHubActionsRole`)

- [ ] **Step 4.11:** Verify **Trust relationships** tab shows:
  - Federated: `token.actions.githubusercontent.com`
  - Condition: Correct repository path

- [ ] **Step 4.12:** Verify **Permissions** tab shows attached policy

---

## Part 5: Security Best Practices (Optional)

### Restrict Trust Policy (Recommended)

- [ ] **Step 5.1:** Decide on access restrictions:
  - Option A: Any branch can deploy (current setup)
  - Option B: Only main branch can deploy
  - Option C: Only specific branches can deploy
  - Option D: Only specific environments can deploy

- [ ] **Step 5.2:** If restricting, update trust policy:
  ```bash
  # For main branch only
  aws iam update-assume-role-policy \
    --role-name GitHubActionsRole \
    --policy-document '{
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Principal": {"Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"},
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringEquals": {"token.actions.githubusercontent.com:aud": "sts.amazonaws.com"},
          "StringLike": {"token.actions.githubusercontent.com:sub": "repo:ORG/REPO:ref:refs/heads/main"}
        }
      }]
    }'
  ```

### Enable MFA for Manual Changes

- [ ] **Step 5.3:** Set up AWS account MFA (if not already)

- [ ] **Step 5.4:** Require MFA for IAM role modifications

### Set Up Alerts

- [ ] **Step 5.5:** Create CloudWatch alarm for:
  - Failed `AssumeRoleWithWebIdentity` attempts
  - Unusual AWS API activity from the role

### Regular Auditing

- [ ] **Step 5.6:** Schedule monthly review of:
  - CloudTrail logs for OIDC authentication
  - IAM role permissions
  - Trust policy still matches requirements

---

## Troubleshooting Checklist

If something goes wrong, check:

### Authentication Fails

- [ ] Verify `permissions: id-token: write` in workflow file
- [ ] Check using `configure-aws-credentials@v4` (not v2 or v3)
- [ ] Verify `AWS_ROLE_ARN` secret is correct format
- [ ] Check trust policy repository name matches exactly (case-sensitive)
- [ ] Verify OIDC provider exists in AWS

### Access Denied Errors

- [ ] Check IAM policy is attached to role
- [ ] Verify IAM policy includes required permissions
- [ ] Check resource ARNs in policy are correct
- [ ] Verify no SCP (Service Control Policy) is blocking access

### OIDC Token Issues

- [ ] Check GitHub Actions is up to date
- [ ] Verify workflow syntax is correct
- [ ] Check no branch protection rules blocking workflow
- [ ] Verify repository settings allow workflows

---

## Rollback Plan (If Needed)

If OIDC setup doesn't work and you need to rollback:

- [ ] **Rollback Step 1:** Restore old workflow files from git
  ```bash
  git checkout HEAD~1 -- .github/workflows/backend-cd.yaml
  git checkout HEAD~1 -- .github/workflows/frontend-cd.yaml
  ```

- [ ] **Rollback Step 2:** Re-add access key secrets in GitHub
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`

- [ ] **Rollback Step 3:** Commit and push changes
  ```bash
  git add .github/workflows/
  git commit -m "Rollback: Restore access key authentication"
  git push
  ```

- [ ] **Rollback Step 4:** Test workflows work with access keys

- [ ] **Rollback Step 5:** Debug OIDC setup offline before retrying

---

## Success Criteria

You've successfully set up OIDC when:

✅ AWS OIDC provider exists
✅ IAM role with GitHub trust policy exists  
✅ IAM permissions policy attached to role
✅ GitHub secrets configured (AWS_ROLE_ARN, etc.)
✅ Old access key secrets deleted
✅ Backend workflow runs successfully
✅ Frontend workflow runs successfully
✅ CloudTrail shows AssumeRoleWithWebIdentity events
✅ No "Access Denied" or authentication errors

---

## Documentation Reference

- **Detailed Setup:** `docs/GITHUB_OIDC_SETUP.md`
- **Quick Reference:** `docs/GITHUB_OIDC_QUICK_START.md`
- **How It Works:** `docs/OIDC_FLOW_EXPLAINED.md`
- **Migration Summary:** `docs/OIDC_MIGRATION_SUMMARY.md`

---

## Need Help?

1. Run the verification script:
   ```bash
   ./infrastructure/verify-github-oidc.sh
   ```

2. Check CloudTrail for error details

3. Review troubleshooting section in `docs/GITHUB_OIDC_SETUP.md`

4. Check GitHub Actions logs for detailed error messages

---

**Setup Date:** _______________  
**Completed By:** _______________  
**Role ARN:** _______________  
**Test Status:** ⬜ Passed  ⬜ Failed  

---

## Final Verification

- [ ] All checkboxes above are completed
- [ ] Both workflows tested and working
- [ ] CloudTrail shows successful OIDC authentication
- [ ] Old access keys deleted from GitHub secrets
- [ ] Documentation reviewed and understood
- [ ] Team members notified of change (if applicable)
- [ ] Setup marked as complete

🎉 **Congratulations! You're now using secure OIDC authentication!**

