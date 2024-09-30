output "deploy_role_arn" {
  value = aws_iam_role.deploy.arn
}

output "ssm_document_name" {
  value = module.nixos_deploy_ssm_document.name
}

output "vmimport_bucket" {
  value = module.vmimport.bucket
}