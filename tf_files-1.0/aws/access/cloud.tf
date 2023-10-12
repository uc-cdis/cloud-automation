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

resource "aws_s3_bucket" "access" {
  bucket = var.access_url
}

locals {
  s3_origin_id = "S3-Website-${var.access_url}.s3-website-us-east-1.amazonaws.com"
}


resource "aws_s3_bucket_acl" "access" {
  bucket = aws_s3_bucket.access.id
  acl    = "public-read"
}

resource "aws_s3_bucket_cors_configuration" "access" {
  bucket = aws_s3_bucket.access.id

  cors_rule {
      allowed_headers = ["*"]
      allowed_methods = ["PUT","POST"]
      allowed_origins = ["*"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3000
  }  
}

resource "aws_s3_bucket_website_configuration" "access" {
  bucket = aws_s3_bucket.access.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_cloudfront_distribution" "access" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [var.access_url]
  price_class         = "PriceClass_200"


  origin {
    domain_name = aws_s3_bucket.access.website_endpoint
    origin_id   = local.s3_origin_id
    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn            = var.access_cert
    cloudfront_default_certificate = true
    ssl_support_method             = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "production"
  }
}
