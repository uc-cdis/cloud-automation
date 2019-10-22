data "terraform_remote_state" "org_setup" {
  backend   = "gcs"
  workspace = "${var.env}-${var.prefix_org_setup}"

  config {
    bucket      = "${var.state_bucket_name}"
    prefix      = "${var.prefix_org_setup}"
    credentials = "${file("${var.credential_file}")}"
  }
}

data "terraform_remote_state" "project_setup" {
  backend   = "gcs"
  workspace = "${var.env}-${var.prefix_project_setup}"

  config {
    bucket      = "${var.state_bucket_name}"
    prefix      = "${var.prefix_project_setup}"
    credentials = "${file("${var.credential_file}")}"
  }
}

data "terraform_remote_state" "csoc_project_setup" {
  backend   = "gcs"
  workspace = "${var.tf_state_project_setup_csoc}"

  config {
    bucket      = "${var.state_bucket_name_csoc}"
    prefix      = "${var.prefix_project_setup_csoc}"
    credentials = "${file("${var.credential_file}")}"
  }
}
