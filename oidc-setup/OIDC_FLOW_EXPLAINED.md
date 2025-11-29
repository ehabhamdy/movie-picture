# GitHub OIDC Authentication Flow

## How It Works

```
┌─────────────────────────────────────────────────────────────────────┐
│                         GitHub Actions Workflow                      │
│                                                                       │
│  1. Workflow triggered (push, PR, manual)                           │
│  2. Job requests OIDC token from GitHub                             │
│     - Token contains claims: repo, branch, environment, etc.        │
│     - Token is short-lived (valid for workflow duration)            │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                │ OIDC Token
                                │ (JWT with claims)
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     configure-aws-credentials Action                 │
│                                                                       │
│  3. Action receives OIDC token from GitHub                          │
│  4. Action calls AWS STS AssumeRoleWithWebIdentity                  │
│     - Sends: OIDC token + Role ARN                                  │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                │ AssumeRoleWithWebIdentity Request
                                │ + OIDC Token
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          AWS Security Token Service                  │
│                                                                       │
│  5. AWS validates the OIDC token:                                   │
│     a. Verifies token signature against GitHub's public keys       │
│     b. Checks audience (aud) = "sts.amazonaws.com"                 │
│     c. Checks issuer (iss) = "https://token.actions.githubusercontent.com" │
│     d. Verifies token not expired                                   │
│                                                                       │
│  6. AWS checks IAM Role Trust Policy:                               │
│     a. OIDC provider matches: token.actions.githubusercontent.com   │
│     b. Subject (sub) matches allowed pattern                        │
│        Example: "repo:myorg/myrepo:ref:refs/heads/main"           │
│     c. Any other conditions in trust policy                         │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                │ If validation succeeds
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        AWS Returns Credentials                       │
│                                                                       │
│  7. Temporary credentials issued:                                   │
│     - AWS_ACCESS_KEY_ID                                             │
│     - AWS_SECRET_ACCESS_KEY                                         │
│     - AWS_SESSION_TOKEN                                             │
│     - Expiration time (typically 1 hour)                            │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                │ Temporary Credentials
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     GitHub Actions Workflow                          │
│                                                                       │
│  8. Workflow uses temporary credentials for AWS operations:         │
│     - Push Docker images to ECR                                     │
│     - Deploy to EKS                                                 │
│     - Any other AWS API calls                                       │
│                                                                       │
│  9. Credentials expire when workflow completes                      │
└─────────────────────────────────────────────────────────────────────┘
```

## OIDC Token Claims

The JWT token from GitHub contains these claims:

```json
{
  "iss": "https://token.actions.githubusercontent.com",
  "aud": "sts.amazonaws.com",
  "sub": "repo:myorg/movie-picture:ref:refs/heads/main",
  "repository": "myorg/movie-picture",
  "repository_owner": "myorg",
  "ref": "refs/heads/main",
  "sha": "abc123...",
  "workflow": "Backend Continuous Deployment",
  "actor": "username",
  "run_id": "1234567890",
  "exp": 1234567890,
  "iat": 1234567890
}
```

## Trust Policy Matching

The IAM Role Trust Policy uses these claims to control access:

```json
{
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:myorg/movie-picture:*"
    }
  }
}
```

**What this means:**
- `aud` must be exactly "sts.amazonaws.com"
- `sub` must match the pattern (any branch from myorg/movie-picture)

## Security Benefits

### 1. No Stored Credentials
❌ **Before:** Long-lived access keys stored in GitHub Secrets
- Risk: If GitHub is compromised, attacker has permanent AWS access
- Risk: Keys could be accidentally leaked in logs or code

✅ **After:** No credentials stored anywhere
- GitHub only stores the IAM Role ARN (not a secret)
- Tokens are generated on-demand and expire quickly

### 2. Fine-Grained Access Control
❌ **Before:** Anyone with the secret has full access
- Can't restrict by branch, environment, or workflow

✅ **After:** Access controlled by trust policy
- Can restrict to specific branches: `repo:org/repo:ref:refs/heads/main`
- Can restrict to specific environments: `repo:org/repo:environment:production`
- Can restrict to pull requests only: `repo:org/repo:pull_request`

### 3. Automatic Rotation
❌ **Before:** Manual key rotation required
- Keys typically never rotated
- Rotation requires updating secrets and potentially downtime

✅ **After:** New token for every workflow run
- Tokens expire after 1 hour or when workflow completes
- No manual rotation needed

### 4. Better Auditing
❌ **Before:** CloudTrail shows "IAM User" performed action
- Can't tell which workflow or run used the credentials

✅ **After:** CloudTrail shows role session with details
- Session name includes workflow run ID
- Can trace back to specific GitHub workflow execution

### 5. Reduced Attack Surface
❌ **Before:** Credentials work from anywhere
- If leaked, attacker can use from any location

✅ **After:** Tokens bound to GitHub's identity
- Token only works with AWS when coming from GitHub
- Can't be reused outside of workflow context

## Trust Policy Examples

### Allow Any Branch
```json
"token.actions.githubusercontent.com:sub": "repo:myorg/myrepo:*"
```
Use when: Workflows from any branch need access

### Allow Only Main Branch
```json
"token.actions.githubusercontent.com:sub": "repo:myorg/myrepo:ref:refs/heads/main"
```
Use when: Only production deployments from main need access

### Allow Multiple Specific Branches
```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": [
    "repo:myorg/myrepo:ref:refs/heads/main",
    "repo:myorg/myrepo:ref:refs/heads/develop"
  ]
}
```
Use when: Multiple deployment branches exist

### Allow Only Specific Environment
```json
"token.actions.githubusercontent.com:sub": "repo:myorg/myrepo:environment:production"
```
Use when: Using GitHub Environments for deployment approval

### Allow Pull Requests
```json
"token.actions.githubusercontent.com:sub": "repo:myorg/myrepo:pull_request"
```
Use when: PRs need to run integration tests against AWS

### Combined Conditions
```json
{
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
    "token.actions.githubusercontent.com:repository_owner": "myorg"
  },
  "StringLike": {
    "token.actions.githubusercontent.com:sub": "repo:myorg/myrepo:*"
  }
}
```
Use when: Extra validation needed (e.g., prevent org transfers)

## Comparison: Access Keys vs OIDC

| Aspect | Access Keys | OIDC |
|--------|------------|------|
| **Storage** | Stored in GitHub Secrets | Not stored (ARN only) |
| **Lifetime** | Permanent until rotated | Minutes (per workflow) |
| **Rotation** | Manual | Automatic |
| **Scope** | Global (any IAM permissions) | Repository/Branch specific |
| **Revocation** | Delete key (affects all uses) | Change trust policy |
| **Auditing** | Generic "IAM User" | Specific role session |
| **Leak Risk** | High (permanent access) | Low (time-limited token) |
| **Setup Complexity** | Low | Medium |
| **Ongoing Maintenance** | High (rotation needed) | Low (automatic) |
| **Security Posture** | Basic | Advanced |
| **Compliance** | May not meet standards | Meets best practices |

## Workflow Changes Required

### Minimal Changes
The workflow changes are minimal:

**1. Add permissions block:**
```yaml
permissions:
  id-token: write
  contents: read
```

**2. Update configure-aws-credentials:**
```yaml
- uses: aws-actions/configure-aws-credentials@v4  # v2 -> v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}   # Instead of access keys
    role-session-name: GitHubActions-${{ github.run_id }}
    aws-region: ${{ secrets.AWS_REGION }}
```

**3. Everything else stays the same!**
- ECR login works the same
- kubectl works the same
- All AWS CLI commands work the same

The temporary credentials are automatically set as environment variables and work exactly like access keys for the duration of the workflow.

## Troubleshooting Flow

```
Workflow Fails
    │
    ├─→ "No OIDC token"
    │   └─→ Add: permissions: id-token: write
    │
    ├─→ "Not authorized to assume role"
    │   ├─→ Check: Repository name in trust policy matches exactly
    │   ├─→ Check: OIDC provider ARN is correct
    │   ├─→ Check: Audience is "sts.amazonaws.com"
    │   └─→ Check: Subject pattern allows this branch
    │
    ├─→ "Access Denied" on AWS resource
    │   ├─→ Check: Policy attached to role
    │   ├─→ Check: Policy has required permissions
    │   └─→ Check: Resource ARNs in policy are correct
    │
    └─→ "Invalid identity token"
        └─→ Check: OIDC provider thumbprint is current
```

## CloudTrail Example

When using OIDC, CloudTrail shows:

```json
{
  "eventName": "AssumeRoleWithWebIdentity",
  "userIdentity": {
    "type": "WebIdentityUser",
    "principalId": "arn:aws:sts::123456789012:assumed-role/GitHubActionsRole/GitHubActions-1234567890",
    "userName": "GitHubActions-1234567890"
  },
  "requestParameters": {
    "roleArn": "arn:aws:iam::123456789012:role/GitHubActionsRole",
    "roleSessionName": "GitHubActions-1234567890"
  },
  "resources": [
    {
      "accountId": "123456789012",
      "type": "AWS::IAM::Role",
      "ARN": "arn:aws:iam::123456789012:role/GitHubActionsRole"
    }
  ]
}
```

This makes it easy to:
- Track which workflows are using AWS
- Audit what actions were taken
- Correlate AWS actions with GitHub workflow runs
- Debug authentication issues

## Summary

OIDC provides:
✅ Better security (no stored credentials)
✅ Automatic credential rotation
✅ Fine-grained access control
✅ Better audit trail
✅ Lower maintenance
✅ Compliance-friendly

With minimal workflow changes!

