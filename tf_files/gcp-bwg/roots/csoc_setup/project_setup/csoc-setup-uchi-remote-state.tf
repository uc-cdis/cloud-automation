data "terraform_remote_state" "org_setup" {
  backend   = "gcs"
  workspace = "${var.env}-${var.prefix_org_setup}"

  config {
    bucket = "${var.state_bucket_name}"

    #bucket = "terraform-state--160215016"
    prefix = "${var.prefix_org_setup}"

    #prefix = "org_setup_csoc"
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

/*
data "google_project" "project" {
    project_id = "aws-tf-csoc-e65b8059"
}
*/

