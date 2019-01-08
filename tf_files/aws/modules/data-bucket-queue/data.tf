#get everything from the existing data upload bucket
data "aws_s3_bucket" "selected" {
  bucket = "${var.bucket_name}"
}
