module "nixos_deploy_ssm_document" {
  source = "../../modules/nixos_deploy_ssm_document"
}

module "nix_cache" {
  source = "../../modules/nix_cache_bucket"
}

module "vmimport" {
  source = "../../modules/vmimport"
}

data "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "build" {
  name = "github-actions-build"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github_actions.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${data.aws_iam_openid_connect_provider.github_actions.url}:sub" = "repo:${var.github_owner}/${var.github_repository}:pull_request"
            "${data.aws_iam_openid_connect_provider.github_actions.url}:sub" = "repo:${var.github_owner}/${var.github_repository}:ref:refs/heads/main"
          }
        }
      },
    ],
  })
}

# Allow Github Actions to upload nix store paths
resource "aws_iam_role_policy_attachment" "build_write_cache" {
  role       = aws_iam_role.build.id
  policy_arn = module.nix_cache.write_policy_arn
}

# Allow Github Actions to upload images
resource "aws_iam_role_policy_attachment" "build_write_vmimport" {
  role       = aws_iam_role.build.id
  policy_arn = module.vmimport.write_policy_arn 
}

resource "github_actions_variable" "BUILD_ROLE_ARN" {
  repository    = var.github_repository
  variable_name = "BUILD_ROLE_ARN"
  value         = aws_iam_role.build.arn
}

resource "github_actions_variable" "NIX_STORE_URI" {
  repository    = var.github_repository
  variable_name = "NIX_STORE_URI"
  value         = module.nix_cache.store_uri
}

output "nix_cache" {
  value = merge(module.nix_cache, {
    trusted_public_key = file("${path.module}/key.pub")
  })
}



# Misc global settings


resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

resource "aws_ec2_instance_metadata_defaults" "this" {
  http_tokens                 = "required"
  http_put_response_hop_limit = 2
}

resource "aws_accessanalyzer_analyzer" "external" {
  analyzer_name = "external"
}

resource "aws_resourceexplorer2_index" "aggregator" {
  type = "AGGREGATOR"

}

resource "aws_resourceexplorer2_view" "default_view" {
  name         = "default"
  default_view = true
  included_property {
    name = "tags"
  }
  depends_on = [aws_resourceexplorer2_index.aggregator]
}
