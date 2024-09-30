resource "aws_s3_bucket" "this" {
  bucket_prefix = "nix-cache"
}

data "aws_iam_policy_document" "read" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]
  }
}

resource "aws_iam_policy" "read" {
  name        = "${aws_s3_bucket.this.bucket}-read"
  description = "Policy for reading from the Nix cache bucket"
  policy      = data.aws_iam_policy_document.read.json
}

data "aws_iam_policy_document" "write" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = ["${aws_s3_bucket.this.arn}/*"]
  }
}

resource "aws_iam_policy" "write" {
  name        = "${aws_s3_bucket.this.bucket}-write"
  description = "Policy for writing to the Nix cache bucket"
  policy      = data.aws_iam_policy_document.write.json
}
