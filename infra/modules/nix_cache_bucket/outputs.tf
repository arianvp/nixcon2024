output "bucket" {
  value = aws_s3_bucket.this.bucket
}

output "arn" {
  value = aws_s3_bucket.this.arn
}

output "region" {
  value = aws_s3_bucket.this.region
}

output "store_uri" {
  value = "s3://${aws_s3_bucket.this.bucket}?region=${aws_s3_bucket.this.region}&compression=zstd"
}

output "write_policy_name" {
  value = aws_iam_policy.write.name
}

output "write_policy_arn" {
  value = aws_iam_policy.write.arn
}

output "read_policy_name" {
  value = aws_iam_policy.read.name
}

output "read_policy_arn" {
  value = aws_iam_policy.read.arn
}
