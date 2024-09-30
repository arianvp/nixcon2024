resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]
}

data "github_repository" "this" {
  name = var.github_repository
}

resource "github_branch_protection" "main" {
  repository_id       = data.github_repository.this.node_id
  pattern             = "main"
  allows_force_pushes = true
}

resource "aws_s3_bucket" "tfstate" {
  bucket_prefix = "tfstate"
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "tflock" {
  name         = "tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_caller_identity" "this" {}

resource "aws_iam_role" "plan" {
  name = "github-actions-plan"
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
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        },
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_owner}/${var.github_repository}:pull_request",
              "repo:${var.github_owner}/${var.github_repository}:ref:refs/heads/main",
            ]
          }
        }
      }
    ],
  })
}

resource "aws_iam_policy" "get_state" {
  name = "github-actions-get-state"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]
        Resource = aws_s3_bucket.tfstate.arn
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
        ],
        Resource = "${aws_s3_bucket.tfstate.arn}/${var.github_repository}/*/terraform.tfstate",
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
        ],
        Resource = aws_dynamodb_table.tflock.arn,
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "plan_get_state" {
  role       = aws_iam_role.plan.name
  policy_arn = aws_iam_policy.get_state.arn
}

resource "aws_iam_role_policy_attachment" "plan_read_only_access" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "github_actions_variable" "plan_role_arn" {
  repository    = var.github_repository
  variable_name = "PLAN_ROLE_ARN"
  value         = aws_iam_role.plan.arn
}


resource "github_actions_environment_secret" "name" {
  repository  = var.github_repository
  environment = "prod"
  secret_name = "NIX_PRIVATE_KEY"
}
