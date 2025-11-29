variable "k8s_version" {
  default = "1.25"
}

variable "enable_private" {
  default = false
}

variable "public_az" {
  type        = string
  description = "Change this to a letter a-f only if you encounter an error during setup"
  default     = "a"
}

variable "private_az" {
  type        = string
  description = "Change this to a letter a-f only if you encounter an error during setup"
  default     = "b"
}

variable "github_org" {
  type        = string
  description = "GitHub organization or username"
  default     = "YOUR_GITHUB_ORG"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
  default     = "YOUR_REPO_NAME"
}
