data "aws_region" "current" {
}

resource "github_actions_variable" "aws_region" {
  repository    = var.github_repository
  variable_name = "AWS_REGION"
  value         = data.aws_region.current.name
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]
}

data "github_repository" "this" {
  name = var.github_repository
}

resource "github_branch_protection" "main" {
  repository_id = data.github_repository.this.node_id
  pattern       = "main"
}


resource "aws_s3_bucket" "tfstate" {
  bucket_prefix = "tfstate"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
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
}

module "prod_environment" {
  source                           = "../modules/github_environment"
  name                             = "prod"
  github_owner                     = var.github_owner
  github_repository                = var.github_repository
  deployment_policy_branch_pattern = "main"
  state_bucket                     = aws_s3_bucket.tfstate
  lock_table                       = aws_dynamodb_table.tflock

  depends_on = [aws_iam_openid_connect_provider.github_actions]
}
