module "bootstrap_environment" {
  source                           = "../../modules/github_environment"
  name                             = "bootstrap"
  github_owner                     = var.github_owner
  github_repository                = var.github_repository
  deployment_policy_branch_pattern = "main"
  state_bucket                     = aws_s3_bucket.tfstate
  lock_table                       = aws_dynamodb_table.tflock
  oidc_provider                    = aws_iam_openid_connect_provider.github_actions
  deploy_role_policies = [
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/IAMFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess",
  ]
}

module "global_environment" {
  source                           = "../../modules/github_environment"
  name                             = "global"
  github_owner                     = var.github_owner
  github_repository                = var.github_repository
  deployment_policy_branch_pattern = "main"
  state_bucket                     = aws_s3_bucket.tfstate
  lock_table                       = aws_dynamodb_table.tflock
  oidc_provider                    = aws_iam_openid_connect_provider.github_actions
  deploy_role_policies = [
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/IAMFullAccess",
    "arn:aws:iam::aws:policy/AmazonSSMFullAccess",
  ]
}

module "prod_environment" {
  source                           = "../../modules/github_environment"
  name                             = "prod"
  github_owner                     = var.github_owner
  github_repository                = var.github_repository
  deployment_policy_branch_pattern = "main"
  state_bucket                     = aws_s3_bucket.tfstate
  lock_table                       = aws_dynamodb_table.tflock
  oidc_provider                    = aws_iam_openid_connect_provider.github_actions
  deploy_role_policies = [
    "arn:aws:iam::aws:policy/IAMFullAccess",
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/AmazonRDSFullAccess",
  ]
}

/*module "staging_environment" {
  source                           = "../../modules/github_environment"
  name                             = "staging"
  github_owner                     = var.github_owner
  github_repository                = var.github_repository
  deployment_policy_branch_pattern = "staging"
  state_bucket                     = aws_s3_bucket.tfstate
  lock_table                       = aws_dynamodb_table.tflock
  oidc_provider                    = aws_iam_openid_connect_provider.github_actions
  deploy_role_policies = [
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/AmazonRDSFullAccess",
  ]
}*/



