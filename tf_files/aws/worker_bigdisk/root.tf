terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

module "worker_bigdisk" {
  source           = "../modules/worker-bigdisk"
  instance_ip  = "${var.instance_ip}"
  volume_size = "${var.volume_size}"

  # put other variables here ...
}

