data "terraform_remote_state" "org_setup" {
  backend   = "gcs"
  workspace = "${var.terraform_workspace}"

  config {
    bucket      = "${var.state_bucket_name}"
    prefix      = "${var.prefix_org_setup}"
    credentials = "${file("${var.credential_file}")}"
  }
}

data "terraform_remote_state" "project_setup" {
  backend   = "gcs"
  workspace = "${var.terraform_workspace}"

  config {
    bucket      = "${var.state_bucket_name}"
    prefix      = "${var.prefix_project_setup}"
    credentials = "${file("${var.credential_file}")}"
  }
}
