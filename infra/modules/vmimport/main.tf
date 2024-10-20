resource "aws_s3_bucket" "vmimport" {
  bucket_prefix = "vmimport"
}

resource "aws_iam_role" "vmimport" {
  name = "vmimport"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vmie.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = "vmimport"
        }
      }
    }]
  })
}


resource "aws_iam_role_policy" "vmimport" {
  role = "vmimport"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
        ]
        Resource = [
          aws_s3_bucket.vmimport.arn,
          "${aws_s3_bucket.vmimport.arn}/*",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSnapshots",
          "ec2:ModifySnapshotAttribute",
          "ec2:CopySnapshot",
          "ec2:DescribeSnapshots",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "write" {
  name = "vmimport-write"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
        ]
        Resource = ["${aws_s3_bucket.vmimport.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]
        Resource = [aws_s3_bucket.vmimport.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:ImportSnapshot",
          "ec2:DescribeImportSnapshotTasks",
          "ec2:DescribeSnapshots",
          "ec2:DeleteSnapshot",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["ec2:CreateTags"],
        Resource = [
          "arn:aws:ec2:*:*:snapshot/*",
          "arn:aws:ec2:*:*:image/*",
          "arn:aws:ec2:*:*:import-snapshot-task/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:DescribeImages",
          "ec2:RegisterImage",
          "ec2:DeregisterImage",
          "ec2:DescribeRegions",
          "ec2:CopyImage",
          "ec2:ModifyImageAttribute",
          "ec2:DisableImageBlockPublicAccess",
          "ec2:EnableImageDeprecation"
        ]
        Resource = "*"
      }
    ]
  })
}

output "bucket" {
  value = aws_s3_bucket.vmimport.bucket
}

output "write_policy_arn" {
  value = aws_iam_policy.write.arn
}
