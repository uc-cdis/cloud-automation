terraform {
  backend "s3" {
    encrypt = "true"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_s3_bucket" "sftp_bucket" {
  bucket = var.s3_bucket_name
}


resource "aws_s3_bucket_server_side_encryption_configuration" "sftp_bucket" {
  bucket = aws_s3_bucket.sftp_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


resource "aws_iam_role" "sftp_role" {
  name = "sftp_role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
            "Service": "transfer.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "sftp" {
  name = "sftp_policy"
  role = aws_iam_role.sftp_role.id

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:Put*",
                "s3:List*",
                "s3:Get*"
            ],
            "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.sftp_bucket.bucket}",
                "arn:aws:s3:::${aws_s3_bucket.sftp_bucket.bucket}/*"
            ]
        }
    ]
}
POLICY
}

resource "aws_transfer_server" "sftp_server" {
  identity_provider_type = "SERVICE_MANAGED"
  logging_role           = aws_iam_role.sftp_role.arn
}

resource "aws_transfer_user" "sftp_user" {
  server_id      = aws_transfer_server.sftp_server.id
  user_name      = "sftp_user"
  role           = aws_iam_role.sftp_role.arn
  home_directory = "/${aws_s3_bucket.sftp_bucket.bucket}/sftp_user"
}

resource "aws_transfer_ssh_key" "ssh_keys" {
  server_id = aws_transfer_server.sftp_server.id
  user_name = aws_transfer_user.sftp_user.user_name
  body      = var.ssh_key
}
