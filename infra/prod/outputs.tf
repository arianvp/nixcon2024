output "deploy_role_arn" {
  value = aws_iam_role.deploy.arn
}

output "ssm_document_name" {
  value = module.nixos_deploy_ssm_document.name
}

output "database_arn" {
  value = module.aurora.arn
}

output "database_reader_endpoint" {
  value = module.aurora.reader_endpoint
}

output "database_writer_endpoint" {
  value = module.aurora.writer_endpoint
}

output "database_master_user_secret_arn" {
  value = module.aurora.master_user_secret_arn
}