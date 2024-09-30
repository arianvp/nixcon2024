locals {
  master_user_secret_arn = aws_rds_cluster.this.master_user_secret[0].secret_arn
}