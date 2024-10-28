
locals {
  availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

data "terraform_remote_state" "global" {
  backend = "s3"
  config = {
    region = "eu-central-1"
    bucket = "tfstate20241018134105449900000001"
    key    = "nixcon2024/global/terraform.tfstate"
  }
}

module "vpc" {
  source             = "../../modules/vpc"
  name               = "nixcon2024"
  availability_zones = local.availability_zones
}


module "aurora" {
  count              = 0
  source             = "../../modules/aurora"
  cluster_identifier = "nixcon2024"
  vpc_id             = module.vpc.id
  subnet_ids         = module.vpc.private_subnets
  availability_zones = local.availability_zones
  instance_count     = 0
}

resource "aws_security_group" "instance" {
  name   = "instance"
  vpc_id = module.vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "ingress_eice" {
  security_group_id            = aws_security_group.instance.id
  referenced_security_group_id = module.vpc.eic_endpoint_security_group_id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ingress_prometheus_node_exporter" {
  security_group_id            = aws_security_group.instance.id
  referenced_security_group_id = aws_security_group.prometheus.id
  from_port                    = 9100
  to_port                      = 9100
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "egress_ipv4" {
  security_group_id = aws_security_group.instance.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "egress_ipv6" {
  security_group_id = aws_security_group.instance.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1"
}


module "website" {
  source             = "../../modules/website"
  name               = "website-prod"
  nix_cache          = data.terraform_remote_state.global.outputs.nix_cache
  instance_type      = "t3a.small"
  architecture       = "x86_64"
  key_name           = "framework"
  vpc_id             = module.vpc.id
  security_group_ids = [aws_security_group.instance.id]
  public_subnets     = module.vpc.public_subnets
  private_subnets    = module.vpc.private_subnets
}

resource "aws_security_group" "prometheus" {
  name   = "prometheus"
  vpc_id = module.vpc.id
}

resource "aws_instance" "prometheus" {
  ami           = data.aws_ami.nixos.id
  instance_type = "t4g.small"
  key_name      = "framework"
  subnet_id     = module.vpc.private_subnets[0]
  security_groups = [
    aws_security_group.prometheus.id,
    aws_security_group.instance.id
  ]
  tags = {
    Role = "prometheus"
  }
}

resource "aws_ssm_association" "deploy_prometheus" {
  name = "NixOS-Deploy"
  targets {
    key    = "tag:Role"
    values = ["prometheus"]
  }
}
