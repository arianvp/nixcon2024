
locals {
  availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

module "vpc" {
  source             = "../../modules/vpc"
  name               = "nixcon2024"
  availability_zones = local.availability_zones
}

module "aurora" {
  count              = 1
  source             = "../../modules/aurora"
  cluster_identifier = "nixcon2024"
  vpc_id             = module.vpc.id
  subnet_ids         = [for v in module.vpc.private_subnets : v.id]
  availability_zones = local.availability_zones
  instance_count     = 0
}

module "vmimport" {
  source = "../../modules/vmimport"
}

module "nix_cache_bucket" {
  source = "../../modules/nix_cache_bucket"
}

module "nixos_deploy_ssm_document" {
  source = "../../modules/nixos_deploy_ssm_document"
}

resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
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

resource "aws_iam_role_policy_attachment" "nixos" {
  role       = aws_iam_role.nixos.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "nixos_admin" {
  role       = aws_iam_role.nixos.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "read_cache" {
  role       = aws_iam_role.nixos.name
  policy_arn = module.nix_cache_bucket.read_policy_arn
}


resource "aws_iam_instance_profile" "nixos" {
  name = "nixos"
  role = aws_iam_role.nixos.name
}

resource "aws_security_group" "nixos" {
  name   = "nixos"
  vpc_id = module.vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "nixos_ssh" {
  security_group_id            = aws_security_group.nixos.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.vpc.eic_endpoint_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "egress" {
  security_group_id = aws_security_group.nixos.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "egress_ipv6" {
  security_group_id = aws_security_group.nixos.id
  ip_protocol       = "-1"
  cidr_ipv6         = "::/0"
}


resource "aws_instance" "nixos" {
  count                       = 0
  ami                         = data.aws_ami.nixos_x86_64.id
  instance_type               = "t3a.medium"
  iam_instance_profile        = aws_iam_instance_profile.nixos.id
  subnet_id                   = module.vpc.public_subnets["eu-central-1a"].id
  vpc_security_group_ids      = [aws_security_group.nixos.id]
  associate_public_ip_address = true
  root_block_device {
    volume_size = 64
    throughput  = 1000
    iops        = 4000
    tags = {
      Name = "nixos"
    }
  }
  tags = {
    Name = "nixos"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "test_new_image" {
  count = 0
  ami   = "ami-007c4f1667cbe2607"
  // This doesn't boot. drops me in an EFI shell
  #instance_type = "t3a.medium"
  instance_type               = "t3a.medium"
  iam_instance_profile        = aws_iam_instance_profile.nixos.id
  subnet_id                   = module.vpc.public_subnets["eu-central-1a"].id
  vpc_security_group_ids      = [aws_security_group.nixos.id]
  associate_public_ip_address = true
  lifecycle {
    create_before_destroy = true
  }
}

locals {
  trusted_public_key = "lol"
}

resource "aws_ssm_association" "web" {
  association_name = "web"
  name             = module.nixos_deploy_ssm_document.name
  targets {
    key    = "tag:Name"
    values = ["nixos"]
  }
}
