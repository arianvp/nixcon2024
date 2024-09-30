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

output "bucket" {
  value = aws_s3_bucket.vmimport.bucket
}
