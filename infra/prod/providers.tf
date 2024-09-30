provider "aws" {
}

provider "postgresql" {
  aws_rds_iam_auth = true
}
