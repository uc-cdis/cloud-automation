resource "aws_s3_bucket" "access" {
  bucket = "${var.access_url}"
  acl = "public-read"
  cors_rule {
      allowed_headers = ["\*"]
      allowed_methods = ["PUT","POST"]
      allowed_origins = ["\*"]
      expose_headers = ["ETag"]
      max_age_seconds = 3000
  }
  policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
    {
        "Sid": "PublicReadForGetBucketObjects",
        "Effect": "Allow",
        "Principal": {
            "AWS": "\*"
         },
         "Action": "s3:GetObject",
         "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/\*"
    }, {
        "Sid": "",
        "Effect": "Allow",
        "Principal": {
            "AWS": "${aws_iam_user.prod_user.arn}"
        },
        "Action": "s3:\*",
        "Resource": [
            "arn:aws:s3:::YOUR-BUCKET-NAME",
            "arn:aws:s3:::YOUR-BUCKET-NAME/\*"
        ]
    }]
}
EOF
}

locals {
  s3_origin_id = "S3-Website-${var.access_url}.s3-website-us-east-1.amazonaws.com"
}

resource "aws_cloudfront_distribution" "access" {
  origin {
    domain_name = "${var.access_url}"
    origin_id   = "${local.s3_origin_id}"


  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = "mylogs.s3.amazonaws.com"
    prefix          = "myprefix"
  }

  aliases = ["${var.access_url}"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_200"

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    acm_certificate_arn = "${var.access_cert}"
    cloudfront_default_certificate = true
    ssl_support_method = "sni-only"

  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}