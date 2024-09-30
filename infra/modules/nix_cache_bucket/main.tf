resource "aws_s3_bucket" "this" {
  bucket_prefix = "nix-cache"
  tags = {
    Name = "nix-cache"
  }
}

resource "aws_iam_policy" "read" {
  name        = "${aws_s3_bucket.this.bucket}-read"
  description = "Policy for reading from the Nix cache bucket"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "s3:GetObject",
      ],
      Resource = "${aws_s3_bucket.this.arn}/*",
    }]
  })
}

resource "aws_iam_policy" "write" {
  name        = "${aws_s3_bucket.this.bucket}-write"
  description = "Policy for writing to the Nix cache bucket"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts",
      ],
      Resource = "${aws_s3_bucket.this.arn}/*",
    }]
  })
}
