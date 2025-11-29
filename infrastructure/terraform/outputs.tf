output "frontend_ecr" {
  value = aws_ecr_repository.frontend.repository_url
}
output "backend_ecr" {
  value = aws_ecr_repository.backend.repository_url
}

output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_version" {
  value = aws_eks_cluster.main.version
}

output "aws_region" {
  value = "us-east-1"
}

# output "aws_account_id" {
#   value = data.aws_caller_identity.current.account_id
# }

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "ARN of the IAM role for GitHub Actions OIDC"
}

output "github_oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.github_actions.arn
  description = "ARN of the GitHub OIDC provider"
}

# output "github_action_user_arn" {
#   value = aws_iam_user.github_action_user.arn
# }
