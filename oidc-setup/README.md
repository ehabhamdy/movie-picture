# GitHub OIDC Authentication Setup

This directory contains comprehensive documentation and automation scripts for setting up OpenID Connect (OIDC) authentication between GitHub Actions and AWS.

## 🎯 What This Is

OIDC allows GitHub Actions workflows to authenticate with AWS without storing long-lived access keys. Instead, GitHub generates short-lived tokens that AWS validates, providing better security with minimal workflow changes.

## 📚 Documentation Guide

Choose the documentation that fits your needs:

### For First-Time Setup

1. **START HERE:** [OIDC Setup Checklist](./OIDC_SETUP_CHECKLIST.md)
   - Step-by-step instructions with checkboxes
   - Perfect for following along during setup
   - Includes troubleshooting and rollback plans

2. **THEN READ:** [Quick Start Guide](./GITHUB_OIDC_QUICK_START.md)
   - 5-step setup process overview
   - Quick reference for common tasks
   - Before/after workflow comparisons

### For Understanding How It Works

3. [OIDC Flow Explained](./OIDC_FLOW_EXPLAINED.md)
   - Visual diagrams of authentication flow
   - Security benefits explained
   - Trust policy examples
   - Comparison: Access Keys vs OIDC

### For Detailed Information

4. [Complete Setup Guide](./GITHUB_OIDC_SETUP.md)
   - Comprehensive technical documentation
   - Multiple configuration options
   - Advanced troubleshooting
   - All available trust policy patterns

### For Project Context

5. [Migration Summary](./OIDC_MIGRATION_SUMMARY.md)
   - What was changed in this project
   - Files modified
   - Next steps
   - Pre-deployment checklist

## 🚀 Quick Start (5 Minutes)

### Prerequisites
- AWS CLI configured with admin permissions
- Access to GitHub repository settings

### Step 1: Run Setup Script
```bash
cd infrastructure
./setup-github-oidc.sh
```

### Step 2: Add GitHub Secret
1. Go to GitHub repository → Settings → Secrets → Actions
2. Add secret: `AWS_ROLE_ARN` = (ARN from script output)
3. Delete old secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`

### Step 3: Test
1. Go to Actions tab
2. Run "Backend Continuous Deployment" workflow
3. Verify authentication succeeds

✅ Done! You're now using secure OIDC authentication.

## 🛠️ Available Scripts

### Setup Script
```bash
./infrastructure/setup-github-oidc.sh
```
- Creates OIDC provider in AWS
- Creates IAM role with trust policy
- Attaches permissions
- **Run this first!**

### Verification Script
```bash
./infrastructure/verify-github-oidc.sh
```
- Checks if OIDC provider exists
- Validates IAM role configuration
- Verifies permissions
- **Run this to debug issues**

## 📋 What Was Changed

### Workflow Files Updated
- ✅ `.github/workflows/backend-cd.yaml`
- ✅ `.github/workflows/frontend-cd.yaml`

### Key Changes
1. Added `permissions: id-token: write`
2. Updated to `configure-aws-credentials@v4`
3. Replaced access keys with `role-to-assume`
4. Updated ECR login to v2

### GitHub Secrets Required
| Secret | Description |
|--------|-------------|
| `AWS_ROLE_ARN` | IAM role ARN (from setup script) |
| `AWS_REGION` | Your AWS region |
| `EKS_CLUSTER_NAME` | Your EKS cluster name |
| `ECR_BACKEND_REPO` | Backend ECR repository |
| `ECR_FRONTEND_REPO` | Frontend ECR repository |

### Secrets to Remove
- ❌ `AWS_ACCESS_KEY_ID`
- ❌ `AWS_SECRET_ACCESS_KEY`

## 🔐 Security Benefits

| Before (Access Keys) | After (OIDC) |
|---------------------|--------------|
| ❌ Long-lived credentials | ✅ Short-lived tokens |
| ❌ Stored in GitHub | ✅ Not stored anywhere |
| ❌ Manual rotation | ✅ Automatic rotation |
| ❌ Global access | ✅ Fine-grained control |
| ❌ Generic audit logs | ✅ Detailed audit trail |

## 📖 Documentation Overview

```
docs/
├── README.md                      ← You are here
├── OIDC_SETUP_CHECKLIST.md       ← Step-by-step setup
├── GITHUB_OIDC_QUICK_START.md    ← Quick reference
├── OIDC_FLOW_EXPLAINED.md        ← How it works
├── GITHUB_OIDC_SETUP.md          ← Complete guide
└── OIDC_MIGRATION_SUMMARY.md     ← What changed

infrastructure/
├── setup-github-oidc.sh          ← Automated setup
├── verify-github-oidc.sh         ← Verification
└── templates/
    ├── github-oidc-trust-policy.json
    └── github-actions-permissions-policy.json
```

## 🎓 Learning Path

### Beginner
Start with these in order:
1. [Migration Summary](./OIDC_MIGRATION_SUMMARY.md) - See what changed
2. [Setup Checklist](./OIDC_SETUP_CHECKLIST.md) - Follow step-by-step
3. [Quick Start](./GITHUB_OIDC_QUICK_START.md) - Keep as reference

### Intermediate
After setup, read:
1. [OIDC Flow Explained](./OIDC_FLOW_EXPLAINED.md) - Understand how it works
2. [Complete Setup Guide](./GITHUB_OIDC_SETUP.md) - Learn advanced options

### Advanced
For customization:
1. Modify trust policy for specific branches
2. Create separate roles for different environments
3. Set up custom permissions policies
4. Configure CloudWatch alarms for monitoring

## ⚠️ Important Notes

### Before You Start
- ✅ Backup your current workflow files
- ✅ Ensure you have AWS admin permissions
- ✅ Test in a non-production environment first
- ✅ Notify team members of the change

### During Setup
- ⚠️ Don't delete old access keys until OIDC works
- ⚠️ Save the Role ARN - you'll need it for GitHub
- ⚠️ Test thoroughly before removing fallback

### After Setup
- ✅ Monitor first few workflow runs
- ✅ Check CloudTrail for authentication events
- ✅ Review and adjust trust policy if needed
- ✅ Update team documentation

## 🐛 Troubleshooting

### Quick Fixes

**Problem:** "Not authorized to perform sts:AssumeRoleWithWebIdentity"
```bash
# Run verification script
./infrastructure/verify-github-oidc.sh

# Check trust policy
aws iam get-role --role-name GitHubActionsRole \
  --query 'Role.AssumeRolePolicyDocument'
```

**Problem:** "No OIDC token available"
- Check workflow has: `permissions: id-token: write`
- Verify using `configure-aws-credentials@v4`

**Problem:** "Access Denied" on AWS resources
```bash
# Check attached policies
aws iam list-attached-role-policies --role-name GitHubActionsRole
```

### Get Help
1. Run `./infrastructure/verify-github-oidc.sh`
2. Check [Complete Setup Guide](./GITHUB_OIDC_SETUP.md) troubleshooting section
3. Review CloudTrail logs for detailed errors
4. Check GitHub Actions workflow logs

## 🔄 Rollback Plan

If something goes wrong:

```bash
# Restore old workflow files
git checkout HEAD~1 -- .github/workflows/backend-cd.yaml
git checkout HEAD~1 -- .github/workflows/frontend-cd.yaml

# Re-add access key secrets in GitHub
# Test workflows work

# Debug OIDC setup before retrying
```

## ✅ Success Checklist

You've successfully set up OIDC when:

- [x] AWS OIDC provider exists
- [x] IAM role created with GitHub trust policy
- [x] Permissions policy attached to role
- [x] GitHub secrets configured
- [x] Old access key secrets deleted
- [x] Workflows run successfully
- [x] CloudTrail shows OIDC authentication
- [x] No authentication errors

## 🎯 Next Steps After Setup

### Immediate
1. Test both backend and frontend workflows
2. Monitor first few runs for issues
3. Remove old access key secrets
4. Update team documentation

### Short Term (Within a Week)
1. Review CloudTrail logs
2. Verify all team members updated
3. Document any custom configurations
4. Set up CloudWatch alarms (optional)

### Long Term (Monthly)
1. Review IAM role permissions
2. Check trust policy still appropriate
3. Audit CloudTrail for unusual activity
4. Update documentation as needed

## 📚 External Resources

- [GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS IAM OIDC Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [configure-aws-credentials Action](https://github.com/aws-actions/configure-aws-credentials)
- [AWS Security Blog: GitHub OIDC](https://aws.amazon.com/blogs/security/use-iam-roles-to-connect-github-actions-to-actions-in-aws/)

## 💡 Tips

### Security
- Use specific branches in trust policy for production
- Create separate roles for different environments
- Review permissions regularly
- Enable CloudTrail logging

### Maintenance
- OIDC requires minimal maintenance
- No credential rotation needed
- Update trust policy as repository structure changes
- Monitor for failed authentication attempts

### Troubleshooting
- Always run verify script first
- Check CloudTrail for detailed errors
- Verify repository names match exactly (case-sensitive)
- Test with workflow_dispatch before enabling on push

## 🤝 Contributing

Found an issue or want to improve the documentation?
1. Create an issue
2. Submit a pull request
3. Update relevant documentation

---

**Last Updated:** November 2025  
**Version:** 1.0  
**Maintainer:** DevOps Team

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│                    OIDC Setup Quick Reference                │
├─────────────────────────────────────────────────────────────┤
│ Setup:        ./infrastructure/setup-github-oidc.sh         │
│ Verify:       ./infrastructure/verify-github-oidc.sh        │
│                                                              │
│ GitHub Secret:  AWS_ROLE_ARN = arn:aws:iam::ACCT:role/NAME │
│                                                              │
│ Workflow:     permissions: id-token: write                  │
│               configure-aws-credentials@v4                   │
│               role-to-assume: ${{ secrets.AWS_ROLE_ARN }}   │
│                                                              │
│ Docs:         docs/OIDC_SETUP_CHECKLIST.md                  │
├─────────────────────────────────────────────────────────────┤
│ Benefits:     ✓ No stored credentials                       │
│               ✓ Automatic rotation                          │
│               ✓ Better security                             │
│               ✓ Fine-grained access                         │
└─────────────────────────────────────────────────────────────┘
```

