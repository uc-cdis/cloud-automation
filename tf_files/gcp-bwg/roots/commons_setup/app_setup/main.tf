#################################################################################
# Log Sink
#################################################################################

module "org_data_access" {
  source      = "../../../modules/stackdriver/org_sink"
  name        = "${var.data_access_sink_name}"
  org_id      = "${var.org_id}"
  destination = "${data.terraform_remote_state.csoc_app_setup.storage_bucket_data_access_name}"
  filter      = "${var.data_access_filter}"
}

module "org_activity" {
  source      = "../../../modules/stackdriver/org_sink"
  name        = "${var.activity_sink_name}"
  org_id      = "${var.org_id}"
  destination = "${data.terraform_remote_state.csoc_app_setup.storage_bucket_activity_name}"
  filter      = "${var.data_access_filter}"
}

# ------------------------------------------------------------------------------
#	CREATE MANAGED INSTANCE GROUPS AUTOHEAL for SQUID
# ------------------------------------------------------------------------------

module "squid_instance_group" {
  source = "../../../modules/compute-group-autoheal"

  name                        = "${var.squid_name}"
  project                     = "${data.terraform_remote_state.org_setup.project_id}"
  network_interface           = "${data.terraform_remote_state.project_setup.network_name_commons_private}"
  subnetwork                  = "${data.terraform_remote_state.project_setup.subnetwork_name__commons_private.0}"
  tags                        = ["${var.inbound_proxy_port_name}", "${var.egress_allow_proxy_mig_name}"]
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
  network        = "${data.terraform_remote_state.project_setup.network_name_commons_private}"
  source_ranges  = "${var.squid_fw_source_ranges}"

  #  target_tags    = "${var.squid_fw_target_tags}"
  target_tags = ["${var.inbound_proxy_port_name}"]
  protocol    = "${var.squid_fw_protocol}"
  ports       = ["${var.squid_hc_tcp_health_check_port}"]
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

# -------------------------------------------------------------------------------
#   CREATE INTERNAL LOAD BALANCER to infront of SQUID MIG
# -------------------------------------------------------------------------------
# Squid

module "squid-ilb" {
  source = "../../../modules/loadbalancer-tcp"
  
  region      = "${var.region}"
  project     = "${data.terraform_remote_state.org_setup.project_id}"
  network     = "${data.terraform_remote_state.project_setup.network_name_commons_private}"
  subnetwork  = "${data.terraform_remote_state.project_setup.subnetwork_name__commons_private.0}"
  name        = "${var.squid_lb_name}"
  ports       = ["${var.squid_hc_tcp_health_check_port}"]
  health_port = "${var.squid_hc_tcp_health_check_port}"

  #target_tags           = "${var.squid_fw_target_tags}"
  target_tags           = "${var.inbound_proxy_port_name}"
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


