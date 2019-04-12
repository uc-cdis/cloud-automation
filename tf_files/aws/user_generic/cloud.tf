terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

resource "aws_iam_access_key" "generic_user_access_key" {
  user    = "${aws_iam_user.generic_user.name}"
  pgp_key = "keybase:some_person_that_exists"
}

resource "aws_iam_user" "generic_user" {
  name = "${var.username}"
  path = "/system/"
}

output "key_id" {
  value = "${aws_iam_access_key.generic_user_access_key.id}"
}
output "key_secret" {
  value = "${aws_iam_access_key.generic_user_access_key.encrypted_secret}"
}
