terraform {
  # Specify terraform code version
  required_version = ">=0.11.7"

  # Specify Google provider version
  required_providers = {
    gcp = ">=2.1.0"
  }
}

provider "google" {
  credentials = "${file("${var.credential_file}")}"
  project     = "${var.project-id}"
  region      = "${var.region}"
}

module "bucket" {
  source      = "../modules/bucket"
  project     = "${var.project-id}"
  bucket_name = ["${var.project-id}-commons"]
}
