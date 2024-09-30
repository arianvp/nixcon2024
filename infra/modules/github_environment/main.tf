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

data "aws_caller_identity" "this" {}

resource "aws_iam_role" "deploy" {
  name = "github-actions-deploy-${var.name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:AssumeRole",
        Principal = {
          AWS = data.aws_caller_identity.this.arn
        }
      },
      {
        Effect = "Allow",
        Action = "sts:AssumeRoleWithWebIdentity",
        Principal = {
          Federated = var.oidc_provider.arn
        },
        Condition = {
          StringEquals = {
            "${var.oidc_provider.url}:sub" = "repo:${var.github_owner}/${var.github_repository}:environment:${var.name}"
          }
        }
    }],
  })
}

resource "aws_iam_policy" "apply" {
  name = "github-actions-deploy-${var.name}"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]
        Resource = var.state_bucket.arn
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ],
        Resource = [
          "${var.state_bucket.arn}/${var.github_repository}/global/terraform.tfstate",
          "${var.state_bucket.arn}/${var.github_repository}/${var.name}/terraform.tfstate"
        ],
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

resource "aws_iam_role_policy_attachment" "deploy" {
  role       = aws_iam_role.deploy.name
  policy_arn = aws_iam_policy.apply.arn
}

resource "aws_iam_role_policy_attachment" "deploy_role_policies" {
  for_each   = var.deploy_role_policies
  role       = aws_iam_role.deploy.name
  policy_arn = each.value
}

resource "github_actions_environment_variable" "deploy" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "DEPLOY_ROLE_ARN"
  value         = aws_iam_role.deploy.arn
}

resource "local_file" "backend" {
  content = jsonencode({
    terraform = {
      backend = {
        s3 = {
          bucket         = var.state_bucket.bucket
          key            = "${var.github_repository}/${var.name}/terraform.tfstate"
          region         = var.state_bucket.region
          dynamodb_table = var.lock_table.name
        }
      }
    }
  })
  filename = "${path.root}/../${var.name}/backend.tf.json"
}
