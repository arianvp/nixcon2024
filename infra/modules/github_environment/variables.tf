variable "oidc_provider" {
  description = "The OIDC provider for GitHub Actions"
  type = object({
    arn = string
    url = string
  })
}
variable "name" {
  description = "The name of the environment"
  type        = string
}

variable "state_bucket" {
  description = "The S3 bucket to store the Terraform state"
  type = object({
    arn    = string
    bucket = string
    region = string
  })
}

variable "lock_table" {
  description = "The DynamoDB table to store the Terraform lock"
  type = object({
    name = string
    arn  = string
  })
}

variable "github_owner" {
  description = "The owner of the GitHub repository"
  type        = string
}

variable "github_repository" {
  description = "The name of the GitHub repository"
  type        = string
}

variable "deployment_policy_branch_pattern" {
  description = "The branch pattern for the deployment policy"
  type        = string
  default     = "main"
}

variable "deploy_role_policies" {
  description = "Additional IAM policies to attach to the role for the environment"
  type        = set(string)
  default     = []
}
