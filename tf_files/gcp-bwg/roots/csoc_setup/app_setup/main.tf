#################################################################################
#  Purpose: Build Bastion Hosts and Admin VM to connect to GKE Private Clusters
#################################################################################

module "compute_instance" {
  source = "../../../modules/compute"

  project         = "${data.terraform_remote_state.org_setup.project_id}"
  count_compute   = "${var.count_compute}"
  instance_name   = "${var.instance_name}"
  region          = "${var.region}"
  environment     = "${var.environment}"
  subnetwork_name = "${data.terraform_remote_state.project_setup.subnetwork_self_link_csoc_private.0}"
  compute_tags    = "${var.compute_tags}"
  compute_labels  = "${var.compute_labels}"
  scopes          = "${var.scopes}"
  ssh_user        = "${var.ssh_user}"
  ssh_key_pub     = "${var.ssh_key_pub}"
  ssh_key         = "${var.ssh_key}"
}

#### END compute_instance MODULE

module "bastion_host" {
  source = "../../../modules/compute"

  project         = "${data.terraform_remote_state.org_setup.project_id}"
  count_compute   = "${var.count_compute}"
  instance_name   = "bastionvm"
  region          = "${var.region}"
  environment     = "${var.environment}"
  subnetwork_name = "${data.terraform_remote_state.project_setup.subnetwork_self_link_csoc_ingress.0}"
  compute_tags    = "${var.bastion_compute_tags}"
  compute_labels  = "${var.compute_labels}"
  scopes          = "${var.scopes}"
  ssh_user        = "${var.ssh_user}"
  ssh_key_pub     = "${var.ssh_key_pub}"
  ssh_key         = "${var.ssh_key}"
}

#### END compute_instance MODULE
#################################################################################
# Stackdriver Log Sink
#################################################################################

module "activity_storage" {
  source        = "../../../modules/bucket"
  bucket_name   = "${var.bucket_activity_logs}"
  project       = "${data.terraform_remote_state.org_setup.project_id}"
  force_destroy = "${var.bucket_destroy}"
  storage_class = "${var.bucket_class}"
}

module "data_access_storage" {
  source        = "../../../modules/bucket"
  bucket_name   = "${var.bucket_data_access_logs}"
  project       = "${data.terraform_remote_state.org_setup.project_id}"
  force_destroy = "${var.bucket_destroy}"
  storage_class = "${var.bucket_class}"
}

module "org_data_access" {
  source      = "../../../modules/stackdriver/org_sink"
  name        = "${var.data_access_sink_name}"
  org_id      = "${var.org_id}"
  destination = "${module.data_access_storage.bucket_name}"
  filter      = "${var.data_access_filter}"
}

module "org_activity" {
  source      = "../../../modules/stackdriver/org_sink"
  name        = "${var.activity_sink_name}"
  org_id      = "${var.org_id}"
  destination = "${module.activity_storage.bucket_name}"
  filter      = "${var.activity_filter}"
}
