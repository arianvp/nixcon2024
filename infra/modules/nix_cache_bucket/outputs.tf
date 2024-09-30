output "bucket" {
  value = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.this.arn
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
