#!/bin/bash

# Quick fix: Add GitHub Actions role to EKS aws-auth ConfigMap
# Simplest approach using eksctl or manual kubectl

set -e

echo "🔧 Quick Fix: Adding GitHub Actions role to EKS"
echo ""

# Get values
CLUSTER_NAME="${1:-cluster}"
REGION="${2:-us-east-1}"

# Get GitHub Actions role ARN
ROLE_ARN=$(aws iam get-role --role-name GitHubActionsRole --query 'Role.Arn' --output text)
echo "✅ Found role: ${ROLE_ARN}"

# Update kubeconfig
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION} --alias ${CLUSTER_NAME}
echo "✅ Updated kubeconfig"

# Get current mapRoles
CURRENT_MAP=$(kubectl get configmap aws-auth -n kube-system -o jsonpath='{.data.mapRoles}')

# Check if already exists
if echo "$CURRENT_MAP" | grep -q "GitHubActionsRole"; then
  echo "✅ Role already exists in aws-auth ConfigMap"
  exit 0
fi

# Backup
BACKUP_FILE="aws-auth-backup-$(date +%Y%m%d-%H%M%S).yaml"
kubectl get configmap aws-auth -n kube-system -o yaml > ${BACKUP_FILE}
echo "✅ Backup created: ${BACKUP_FILE}"

# Download the current ConfigMap
kubectl get configmap aws-auth -n kube-system -o yaml > /tmp/aws-auth.yaml

# Add the GitHub Actions role to the mapRoles section
python3 - <<EOF
import yaml

# Read the ConfigMap
with open('/tmp/aws-auth.yaml', 'r') as f:
    configmap = yaml.safe_load(f)

# Add the new role to mapRoles
current_roles = configmap['data']['mapRoles']
new_role = """
    - rolearn: ${ROLE_ARN}
      username: github-actions
      groups:
        - system:masters"""

configmap['data']['mapRoles'] = current_roles + new_role

# Write back
with open('/tmp/aws-auth-updated.yaml', 'w') as f:
    yaml.dump(configmap, f, default_flow_style=False)

print("✅ Updated ConfigMap created")
EOF

# Apply the updated ConfigMap
kubectl apply -f /tmp/aws-auth-updated.yaml

# Cleanup
rm /tmp/aws-auth.yaml /tmp/aws-auth-updated.yaml

echo ""
echo "✅ SUCCESS! GitHub Actions role added to EKS cluster"
echo "   Role: ${ROLE_ARN}"
echo "   Username: github-actions"
echo "   Groups: system:masters"
echo ""
echo "🎉 Your GitHub Actions workflow should now work!"

