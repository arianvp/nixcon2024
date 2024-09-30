/*variable "image_info" {
  description = "Path to the image info file"
  type        = string
  default = "./result/nix-support/image-info.json"
}

locals {
  image_info = jsondecode(file(var.image_info))
}

resource "aws_s3_bucket" "images" {
  bucket_prefix = "images" 
}

resource "aws_s3_object" "image" {
  bucket = aws_s3_bucket.images.bucket
  key    = local.image_info.label
  source = local.image_info.file
}

resource "aws_iam_role" "vmimport" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vmie.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "vmimport" {
  name   = "vmimport"
  role   = aws_iam_role.vmimport.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:ListBucket",
      ]
      Resource = [
        aws_s3_bucket.images.arn,
        "${aws_s3_bucket.images.arn}/*",
      ]
    },
    {
      Effect   = "Allow"
      Action   = [
        "ec2:ModifySnapshotAttribute",
        "ec2:CopySnapshot",
        "ec2:DescribeSnapshots",
      ]
      Resource = "*"
    }
    ]
  })
}

resource "aws_ebs_snapshot_import" "this" {
  role_name = aws_iam_role.vmimport.name
  disk_container {
    format = "vhd"
    user_bucket {
      s3_bucket = aws_s3_object.image.bucket
      s3_key    = aws_s3_object.image.key
    }
  }
}

resource "aws_ami" "this" {
  name                = local.image_info.label
  architecture        = local.image_info.system == "x86_64-linux" ? "x86_64" : "arm64"
  root_device_name    = "/dev/xvda"
  virtualization_type = "hvm"
  ebs_block_device {
    device_name = "/dev/xvda"
    snapshot_id = aws_ebs_snapshot_import.this.id
  }
}

resource "aws_launch_template" "this" {
  image_id      = aws_ami.this.id
  instance_type = "t4g.nano"
}


resource "aws_autoscaling_group" "this" {
  min_size = 1
  max_size = 1

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }
}*/
