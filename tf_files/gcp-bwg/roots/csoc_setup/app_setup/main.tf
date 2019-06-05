#################################################################################
#  Purpose: Build Bastion Hosts and Admin VM to connect to GKE Private Clusters
#################################################################################

module "compute_instance" {
  source = "../../../modules/compute"

  project         = "${var.project_name}"
  count_compute   = "${var.count_compute}"
  instance_name   = "${var.instance_name}"
  region          = "${var.region}"
  environment     = "${var.environment}"
  subnetwork_name = "${var.subnetwork_name}"

  compute_tags   = "${var.compute_tags}"
  compute_labels = "${var.compute_labels}"
  scopes         = "${var.scopes}"
}
#### END compute_instance MODULE


module "bastion_host" {
  source = "../../../modules/compute"

  project         = "${var.project_name}"
  count_compute   = "${var.count_compute}"
  instance_name   = "bastionvm"
  region          = "${var.region}"
  environment     = "${var.environment}"
  subnetwork_name = "${var.ingress_subnetwork_name}"

  compute_tags   = "${var.bastion_compute_tags}"
  compute_labels = "${var.compute_labels}"
  scopes         = "${var.scopes}"
}
#### END compute_instance MODULE
