# Terraform Infrastructure for Movie Picture

This Terraform configuration sets up the necessary infrastructure for the Movie Picture application.

## Prerequisites

- Terraform installed
- AWS CLI installed and configured
- AWS credentials with appropriate permissions

## Usage

1. Initialize Terraform
```bash
terraform init
```

2. Review the planned changes
```bash
terraform plan
```

3. Apply the changes
```bash
terraform apply
```

4. Update the Kubeconfig
```bash
aws eks update-kubeconfig --name <cluster-name> --region us-east-1
```

5. Verify and copy the context name
```bash
kubectl config get-contexts
```

6. Map GitHub Actions role to EKS cluster
Get the role ARN
```bash
aws iam get-role --role-name GitHubActionsRole --query 'Role.Arn' --output text
```

    Update kubeconfig
```bash
aws eks update-kubeconfig --name <cluster-name> --region us-east-1
```

Edit the aws-auth ConfigMap
```bash
kubectl edit configmap aws-auth -n kube-system    
```

When the editor opens, add this under mapRoles: section:
```yaml
- rolearn: <ROLE_ARN>
  username: github-actions
  groups:
    - system:masters
```

Save and exit the editor.

or you can use the script `add-github-role-to-eks.sh` to add the GitHub Actions role to the EKS cluster: