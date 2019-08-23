# -------------------------------------------------------------------------------
#  Purpose: Build Bastion Hosts and Admin VM to connect to GKE Private Clusters
# -------------------------------------------------------------------------------
module "compute_instance" {
  source = "../../../modules/compute-no-public-ip"

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

module "openvpn_host" {
  source = "../../../modules/compute"

  project         = "${data.terraform_remote_state.org_setup.project_id}"
  count_compute   = "${var.openvpn_count_compute}"
  instance_name   = "${var.openvpn_instance_name}"
  region          = "${var.region}"
  environment     = "${var.environment}"
  subnetwork_name = "${data.terraform_remote_state.project_setup.subnetwork_self_link_csoc_ingress.0}"
  compute_tags    = "${var.openvpn_compute_tags}"
  compute_labels  = "${var.compute_labels}"
  scopes          = "${var.scopes}"
  ssh_user        = "${var.ssh_user}"
  ssh_key_pub     = "${var.ssh_key_pub}"
  ssh_key         = "${var.ssh_key}"
}

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

# -------------------------------------------------------------------------------
#   CREATE MANAGED INSTANCE GROUPS for SQUID
# -------------------------------------------------------------------------------

module "squid_instance_group" {
  source = "../../../modules/compute-group"

  name                        = "${var.squid_name}"
  project                     = "${data.terraform_remote_state.org_setup.project_id}"
  network_interface           = "${data.terraform_remote_state.project_setup.network_name_csoc_egress}"
  subnetwork                  = "${data.terraform_remote_state.project_setup.network_subnetwork_csoc_egress.0}"
  tags                        = "${var.squid_tags}"
  metadata_startup_script     = "${var.squid_metadata_startup_script}"
  machine_type                = "${var.squid_machine_type}"
  base_instance_name          = "${var.squid_base_instance_name}"
  zone                        = "${var.squid_zone}"
  region                      = "${var.region}"
  target_size                 = "${var.squid_target_size}"
  target_pool_name            = "${var.squid_target_pool_name}"
  source_image                = "${var.squid_source_image}"
  instance_template_name      = "${var.squid_instance_template_name}"
  instance_group_manager_name = "${var.squid_instance_group_manager_name}"
  automatic_restart           = "${var.squid_automatic_restart}"
  on_host_maintenance         = "${var.squid_on_host_maintenance}"
  labels                      = "${var.squid_labels}"
  access_config               = "${var.squid_access_config}"
  network_ip                  = "${var.squid_network_ip}"
  can_ip_forward              = "${var.squid_can_ip_forward}"
}

# -------------------------------------------------------------------------------
#   CREATE INTERNAL LOAD BALANCER to infront of SQUID MIG
# -------------------------------------------------------------------------------
# Squid

module "squid-ilb" {
  source = "../../../modules/loadbalancer-tcp"

  region                = "${var.region}"
  project               = "${data.terraform_remote_state.org_setup.project_id}"
  network               = "${data.terraform_remote_state.project_setup.network_name_csoc_egress}"
  subnetwork            = "${data.terraform_remote_state.project_setup.network_subnetwork_csoc_egress.0}"
  name                  = "${var.squid_lb_name}"
  ports                 = "${var.squid_lb_ports}"
  health_port           = "${var.squid_lb_health_port}"
  target_tags           = "${var.squid_lb_target_tags}"
  session_affinity      = "${var.squid_lb_session_affinity}"
  load_balancing_scheme = "${var.squid_lb_load_balancing_scheme}"
  protocol              = "${var.squid_lb_protocol}"
  ip_address            = "${var.squid_lb_ip_address}"
  ip_protocol           = "${var.squid_lb_ip_protocol}"
  http_health_check     = "${var.squid_lb_http_health_check}"
  ports                 = "${var.squid_lb_ports}"

  backends = [
    {
      group = "${module.squid_instance_group.instance_group}"
    },
  ]
}

# -------------------------------------------------------------------------------
#   Stackdriver Log Sink
# -------------------------------------------------------------------------------

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
