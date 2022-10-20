output "log_bucket_name" {
  value = aws_s3_bucket.log_bucket.id
}

output "rw_policy_arn" {
  value = aws_iam_policy.log_bucket_writer.arn
}
