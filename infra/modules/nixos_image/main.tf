variable "name" {
  type = string
}

variable "bucket" {
  type = string
}

variable "nix_store_path" {
  type = string
}

locals {
  image_info = jsondecode(file("${var.nix_store_path}/nix-support/image-info.json"))
}

resource "aws_s3_object" "this" {
  bucket = var.bucket
  key    = "${var.name}-${local.image_info.label}"
  source = local.image_info.file
}

resource "aws_ebs_snapshot_import" "this" {
  disk_container {
    format = "VHD"
    user_bucket {
      s3_bucket = aws_s3_object.this.bucket
      s3_key    = aws_s3_object.this.key
    }
  }
}

resource "aws_ami" "this" {
  name = "${var.name}-${local.image_info.label}"
  ebs_block_device {
    device_name = "/dev/xvda"
    snapshot_id = aws_ebs_snapshot_import.this.snapshot_id
  }
  root_device_name    = "/dev/xvda"
  virtualization_type = "hvm"
  boot_mode           = local.image_info.boot_mode
}

output "image_id" {
  value = aws_ami.this.id
}

