terraform {
  # Specify terraform code version
  required_version = ">=0.11.7"

  # Specify Google provider version
  required_providers = {
    gcp = ">=2.1.0"
  }

  backend "gcs" {}
}

provider "google" {
  credentials = "${file("${var.credential_file}")}"
  region      = "${var.region}"
}

provider "google-beta" {
  credentials = "${file("${var.credential_file}")}"
  region      = "${var.region}"
}
