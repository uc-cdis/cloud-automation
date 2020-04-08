module "data-bucket-queue" {
  source          = "../data-bucket-queue"
  bucket_name     = "${aws_s3_bucket.data_bucket.id}"
  configure_bucket_notifications = false
}
