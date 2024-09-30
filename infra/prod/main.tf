
locals {
  availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

module "vpc" {
  source             = "../modules/vpc"
  name               = "nixcon2024"
  availability_zones = local.availability_zones
}

module "aurora" {
  source             = "../modules/aurora"
  cluster_identifier = "nixcon2024"
  vpc_id             = module.vpc.id
  subnet_ids         = values(module.vpc.private_subnets_ids)
  availability_zones = local.availability_zones
  instance_count     = 1
}

module "nix_cache_bucket" {
  source = "../modules/nix_cache_bucket"
}


module "nixos_deploy_ssm_document" {
  source = "../modules/nixos_deploy_ssm_document"
}

resource "aws_iam_role" "nixos" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

//  The "for_each" set includes values derived from resource attributes that cannot be determined
// until apply, and so OpenTofu cannot determine the full set of keys that will identify the
// instances of this resource.
// 
/*resource "aws_iam_role_policy_attachment" "nixos" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    module.nix_cache_bucket.read_policy_arn,
  ])
  role       = aws_iam_role.nixos.name
  policy_arn = each.key
}*/

resource "aws_iam_instance_profile" "nixos" {
  name = "nixos"
  role = aws_iam_role.nixos.name
}

resource "aws_instance" "nixos_arm64" {
  ami                    = data.aws_ami.nixos_arm64.id
  instance_type          = "t4g.nano"
  iam_instance_profile   = aws_iam_instance_profile.nixos.id
  subnet_id              = module.vpc.private_subnets_ids["eu-central-1a"]
  vpc_security_group_ids = [module.aurora.client_security_group_id]
  tags = {
    Name = "nixos"
  }
}

resource "aws_iam_role" "deploy" {
  name = "deploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { AWS = data.aws_caller_identity.self.arn }
      }
    ]
  })
}

data "aws_iam_policy_document" "nixos_deploy" {
  statement {
    effect    = "Allow"
    actions   = ["ssm:SendCommand"]
    resources = [module.nixos_deploy_ssm_document.arn]
  }
  statement {
    effect    = "Allow"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ec2:*:*:instance/*"]
    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Name"
      values   = ["nixos"]
    }
  }
  statement {
    effect    = "Allow"
    actions   = ["ssm:ListCommands", "ssm:ListCommandInvocations"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "nixos_deploy" {
  policy = data.aws_iam_policy_document.nixos_deploy.json
}


resource "aws_iam_role_policy_attachment" "deploy" {
  role       = aws_iam_role.deploy.name
  policy_arn = aws_iam_policy.nixos_deploy.arn
}
