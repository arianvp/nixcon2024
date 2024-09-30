provider "aws" {
}

provider "postgresql" {
  scheme           = "awspostgres"
  host             = local.database_writer_endpoint
  aws_rds_iam_auth = true
  connect_timeout  = 10
}
