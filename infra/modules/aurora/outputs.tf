
output "client_security_group_id" {
  value = aws_security_group.client.id
}

output "arn" {
  value = aws_rds_cluster.this.arn
}

output "reader_endpoint" {
  value = aws_rds_cluster.this.reader_endpoint
}

output "writer_endpoint" {
  value = aws_rds_cluster.this.endpoint
}

output "master_user_secret_arn" {
  value = local.master_user_secret_arn
}

output "get_master_user_secret_value_policy_arn" {
  value = aws_iam_policy.get_master_user_secret_value.arn
}