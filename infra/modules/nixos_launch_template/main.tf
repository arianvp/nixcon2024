
resource "aws_iam_role" "this" {
  name = "${var.name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = "sts:AssumeRole",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cache" {
  count      = var.nix_cache.read_policy_arn != null ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = var.nix_cache.read_policy_arn
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-ip"
  role = aws_iam_role.this.id
}

data "aws_ami" "nixos" {
  owners      = ["427812963091"]
  most_recent = true

  filter {
    name   = "name"
    values = ["nixos/${var.nixos_version}*"]
  }
  filter {
    name   = "architecture"
    values = [var.architecture]
  }
}

data "aws_default_tags" "this" {}

resource "aws_launch_template" "this" {
  name = "${var.name}-lt"
  iam_instance_profile {
    arn = aws_iam_instance_profile.this.arn
  }
  image_id      = data.aws_ami.nixos.id
  instance_type = var.instance_type
  network_interfaces {
    security_groups = var.security_group_ids
  }
  metadata_options {
    instance_metadata_tags = "enabled"
  }
  key_name  = var.key_name
  user_data = base64encode(file("${path.module}/deploy.sh"))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Installable       = var.installable
      TrustedPublicKeys = var.trusted_public_keys
      Substituters      = var.substituters
    }
  }
}

output "launch_template" {
  value = aws_launch_template.this
}

output "role" {
  value = aws_iam_role.this
}
