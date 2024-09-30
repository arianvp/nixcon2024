resource "github_repository_environment" "this" {
  repository  = var.github_repository
  environment = var.name
  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "this" {
  repository     = var.github_repository
  environment    = github_repository_environment.this.environment
  branch_pattern = "main"
}

data "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_caller_identity" "this" {}

resource "aws_iam_role" "this" {
  name = "github-actions-deploy-${var.name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:AssumeRole",
        Prinicipal = {
          AWS = data.aws_caller_identity.this.arn
        }
      },
      {
        Effect = "Allow",
        Action = "sts:AssumeRoleWithWebIdentity",
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github_actions.arn
        },
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_owner}/${var.github_repository}:environment:${var.name}"
          }
        }
    }],
  })
}

resource "aws_iam_role_policy" "this" {
  name = "github-actions-deploy-${var.name}"
  role = aws_iam_role.this.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ],
        Resource = "${var.state_bucket.arn}/${var.name}/terraform.tfstate",
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
        ],
        Resource = var.lock_table.arn,
      }
    ],
  })
}

resource "github_actions_environment_variable" "this" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "AWS_ROLE_ARN"
  value         = aws_iam_role.this.arn
}

resource "local_file" "backend" {
  content = jsonencode({
    terraform = {
      backend = {
        s3 = {
          bucket         = var.state_bucket.bucket
          key            = "${var.name}/terraform.tfstate"
          region         = var.state_bucket.region
          dynamodb_table = var.lock_table.name
        }
      }
    }
  })
  filename = "${path.root}/../${var.name}/backend.tf.json"
}

output "role" {
  value = aws_iam_role.this
}
