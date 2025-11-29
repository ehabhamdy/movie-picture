#!/bin/bash

# Quick fix: Add GitHub Actions role to EKS aws-auth ConfigMap

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
kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth-backup-$(date +%Y%m%d-%H%M%S).yaml
echo "✅ Backup created"

# Create new mapRoles with GitHub Actions role
cat > /tmp/new-maproles.yaml <<EOF
${CURRENT_MAP}
    - rolearn: ${ROLE_ARN}
      username: github-actions
      groups:
        - system:masters
EOF

# Patch the ConfigMap using kubectl patch with proper JSON format
kubectl patch configmap aws-auth -n kube-system --type strategic -p "{\"data\":{\"mapRoles\":\"$(cat /tmp/new-maproles.yaml | sed 's/"/\\"/g' | awk '{printf "%s\\n",$0}')\"}}"

rm /tmp/new-maproles.yaml

echo ""
echo "✅ SUCCESS! GitHub Actions role added to EKS cluster"
echo "   Role: ${ROLE_ARN}"
echo "   Username: github-actions"
echo "   Groups: system:masters"
echo ""
echo "🎉 Your GitHub Actions workflow should now work!"

