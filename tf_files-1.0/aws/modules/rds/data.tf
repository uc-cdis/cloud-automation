data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "enhanced_monitoring" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "backup_bucket_access_kms" {
  statement {
    actions = ["kms:DescribeKey","kms:GenerateDataKey","kms:Encrypt","kms:Decrypt"]
    resources = ["arn:aws:kms:region:${data.aws_caller_identity.current.account_id}:key/${var.rds_instance_backup_kms_key}"]
    effect = "Allow"
  }

  statement {
    actions = ["s3:ListBucket","s3:GetBucketLocation"]
    resources = ["arn:aws:s3:::${var.rds_instance_backup_bucket_name}"]
    effect = "Allow"
  }

  statement {
    actions = ["s3:GetObject","s3:PutObject","s3:ListMultipartUploadParts","s3:AbortMultipartUpload"]
    resources = ["arn:aws:s3:::${var.rds_instance_backup_bucket_name}"]
    effect = "Allow"
  }
}
