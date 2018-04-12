resource "aws_s3_bucket" "log_bucket" {
  bucket = "s3logs-${local.clean_bucket_name}"
  acl    = "log-delivery-write"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    id      = "log"
    enabled = true

    prefix = "/"

    tags {
      "rule"      = "log"
      "autoclean" = "true"
    }

    expiration {
      days = 120
    }
  }

  tags {
    Name        = "s3logs-${local.clean_bucket_name}"
    Environment = "${var.environment}"
    Purpose     = "logs bucket"
  }
}
