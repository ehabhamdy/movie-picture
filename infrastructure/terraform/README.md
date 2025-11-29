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

