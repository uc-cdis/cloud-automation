
## Get the bucket by its name 
data "aws_s3_bucket" "data-bucket" {
  bucket = "${var.bucket_name}"
}
