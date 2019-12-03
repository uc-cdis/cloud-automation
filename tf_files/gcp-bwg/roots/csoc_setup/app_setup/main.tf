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
  compute_tags = ["${data.terraform_remote_state.project_setup.firewall-csoc-private-inbound-ssh-target-tags}","${data.terraform_remote_state.project_setup.firewall-csoc-private-outbound-ssh-target-tags}","${data.terraform_remote_state.project_setup.firewall-csoc-private-outbound-proxy-target-tags}","${data.terraform_remote_state.project_setup.firewall-csoc-private-inboud-gke-target-tags}","${data.terraform_remote_state.project_setup.firewall-csoc-private-outbound-gke-target-tags}"]
  compute_labels  = "${var.compute_labels}"
  scopes          = "${var.scopes}"
  ssh_user        = "${var.ssh_user}"
  ssh_key_pub     = "${var.ssh_key_pub}"
  ssh_key         = "${var.ssh_key}"
  image_name      = "${var.image_name}"
}

/*
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
*/
#### END compute_instance MODULE
# -------------------------------------------------------------------------------
#   CREATE MANAGED INSTANCE GROUPS for OPENVPN
# -------------------------------------------------------------------------------

module "openvpn_instance_group" {
  source = "../../../modules/compute-group"

  name              = "${var.openvpn_name}"
  project           = "${data.terraform_remote_state.org_setup.project_id}"
  network_interface = "${data.terraform_remote_state.project_setup.network_name_csoc_ingress}"
  subnetwork        = "${data.terraform_remote_state.project_setup.network_subnetwork_csoc_ingress.0}"
  tags = ["${data.terraform_remote_state.project_setup.firewall-csoc-ingress-inbound-openvpn-target-tags}", "${data.terraform_remote_state.project_setup.firewall-csoc-ingress-outbound-proxy-target-tags}", "${data.terraform_remote_state.project_setup.firewall_csoc_egress_allow_openvpn-target-tags}","${data.terraform_remote_state.project_setup.firewall_csoc_ingress_outbound_ssh_target_tags}"]
  metadata_startup_script     = "${var.openvpn_metadata_startup_script}"
  machine_type                = "${var.openvpn_machine_type}"
  base_instance_name          = "${var.openvpn_base_instance_name}"
  zone                        = "${var.openvpn_zone}"
  region                      = "${var.region}"
  target_size                 = "${var.openvpn_target_size}"
  #target_pool_name            = "${var.openvpn_target_pool_name}"
  target_pool_name = ["${module.openvpn-elb.target_pool}"]
  source_image                = "${var.openvpn_source_image}"
  instance_template_name      = "${var.openvpn_instance_template_name}"
  instance_group_manager_name = "${var.openvpn_instance_group_manager_name}"
  automatic_restart           = "${var.openvpn_automatic_restart}"
  on_host_maintenance         = "${var.openvpn_on_host_maintenance}"
  labels                      = "${var.openvpn_labels}"
  access_config               = "${var.openvpn_access_config}"
  network_ip                  = "${var.openvpn_network_ip}"
  can_ip_forward              = "${var.openvpn_can_ip_forward}"
}

# -------------------------------------------------------------------------------
#   CREATE MANAGED INSTANCE GROUPS AUTOHEAL for SQUID
# -------------------------------------------------------------------------------

module "squid_instance_group" {
  source = "../../../modules/compute-group-autoheal"

  name              = "${var.squid_name}"
  project           = "${data.terraform_remote_state.org_setup.project_id}"
  network_interface = "${data.terraform_remote_state.project_setup.network_name_csoc_egress}"
  subnetwork        = "${data.terraform_remote_state.project_setup.network_subnetwork_csoc_egress.0}"
  tags = ["${data.terraform_remote_state.project_setup.firewall-csoc-egress-inboud-proxy-port-target-tags}","${data.terraform_remote_state.project_setup.firewall-csoc-egress-outbound-web-target-tags}"]
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
  hc_name                     = "${var.squid_name}-${var.squid_hc_name}"
  hc_check_interval_sec       = "${var.squid_hc_check_interval_sec}"
  hc_timeout_sec              = "${var.squid_hc_timeout_sec}"
  hc_healthy_threshold        = "${var.squid_hc_healthy_threshold}"
  hc_unhealthy_threshold      = "${var.squid_hc_unhealthy_threshold}"
  hc_tcp_health_check_port    = "${var.squid_hc_tcp_health_check_port}"
}

# -------------------------------------------------------------------------------
#   CREATE FIREWALL RULE FOR HEALTCHECK for SQUID
#   Open from specific Google Owned IPs from probes
#   https://cloud.google.com/load-balancing/docs/health-check-concepts
# -------------------------------------------------------------------------------
module "create_fw_squid_hc_rule" {
  source = "../../../modules/firewall"

  name           = "${var.squid_name}-${var.squid_fw_name}"
  project_id     = "${data.terraform_remote_state.org_setup.project_id}"
  enable_logging = "${var.squid_fw_enable_logging}"
  direction      = "${var.squid_fw_direction}"
  priority       = "${var.squid_fw_priority}"
  network        = "${data.terraform_remote_state.project_setup.network_name_csoc_egress}"
  source_ranges  = "${var.squid_fw_source_ranges}"
  target_tags    = "${var.squid_fw_target_tags}"
  protocol       = "${var.squid_fw_protocol}"
  ports          = ["${var.squid_hc_tcp_health_check_port}"]
}

# -------------------------------------------------------------------------------
#   CREATE AUTOSCALER for OPENVPN
# -------------------------------------------------------------------------------

module "openvpn_create_autoscaler" {
  source = "../../../modules/autoscaler"

  project                = "${data.terraform_remote_state.org_setup.project_id}"
  name                   = "${var.openvpn_name}-autoscaler"
  target_instance_group  = "${module.openvpn_instance_group.instance_group_manager_self_link}"
  zone                   = "${var.openvpn_zone}"
  min_replicas           = "${var.openvpn_min_replicas}"
  max_replicas           = "${var.openvpn_max_replicas}"
  cpu_utilization_target = "${var.openvpn_cpu_utilization_target}"
  cooldown_period        = "${var.openvpn_cooldown_period}"
}

# -------------------------------------------------------------------------------
#   CREATE AUTOSCALER for SQUID
# -------------------------------------------------------------------------------

module "squid_create_autoscaler" {
  source = "../../../modules/autoscaler"

  project                = "${data.terraform_remote_state.org_setup.project_id}"
  name                   = "${var.squid_name}-autoscaler"
  target_instance_group  = "${module.squid_instance_group.instance_group_manager_self_link}"
  zone                   = "${var.squid_zone}"
  min_replicas           = "${var.squid_min_replicas}"
  max_replicas           = "${var.squid_max_replicas}"
  cpu_utilization_target = "${var.squid_cpu_utilization_target}"
  cooldown_period        = "${var.squid_cooldown_period}"
}

# ------------------------------------------------------------------------------
#   CREATE EXTERNAL LOAD BALANCER infront of OPENVPN MIG
# ------------------------------------------------------------------------------
# OpenVPN

module "openvpn-elb" { 
  source = "GoogleCloudPlatform/lb/google"
  version = "~> 1.0.0"
  project = "${data.terraform_remote_state.org_setup.project_id}"
  region = "us-central1"
  name = "${var.openvpn_name}-elb"
  service_port = "${var.openvpn_lb_port}"
  target_tags = ["${data.terraform_remote_state.project_setup.firewall-csoc-ingress-inbound-openvpn-target-tags}", "${data.terraform_remote_state.project_setup.firewall_csoc_egress_allow_openvpn-target-tags}"]
  network = "${data.terraform_remote_state.project_setup.network_name_csoc_ingress}"

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
  ports                 = ["${var.squid_hc_tcp_health_check_port}"]
  health_port           = "${var.squid_hc_tcp_health_check_port}"
  target_tags           = "${var.squid_fw_target_tags}"
  session_affinity      = "${var.squid_lb_session_affinity}"
  load_balancing_scheme = "${var.squid_lb_load_balancing_scheme}"
  protocol              = "${var.squid_fw_protocol}"
  ip_address            = "${var.squid_lb_ip_address}"
  ip_protocol           = "${var.squid_lb_ip_protocol}"
  http_health_check     = "${var.squid_lb_http_health_check}"

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
  labels = "${var.bucket_data_access_logs_labels}"
}

module "data_access_storage" {
  source        = "../../../modules/bucket"
  bucket_name   = "${var.bucket_data_access_logs}"
  project       = "${data.terraform_remote_state.org_setup.project_id}"
  force_destroy = "${var.bucket_destroy}"
  storage_class = "${var.bucket_class}"
  labels        = "${var.bucket_data_access_logs_labels}"
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


