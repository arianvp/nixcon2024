data "aws_availability_zones" "available" {}

data "aws_caller_identity" "self" {}

data "aws_ami" "nixos" {
  owners      = ["427812963091"]
  most_recent = true

  filter {
    name   = "name"
    values = ["nixos/24.05*"]
  }
  filter {
    name   = "architecture"
    values = ["arm64"] 
  }
}