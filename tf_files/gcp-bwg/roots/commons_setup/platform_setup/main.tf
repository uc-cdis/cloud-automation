/**********************************************
*      Create Cloud SQL commons
**********************************************/
module "sql" {
  source = "../../../modules/sql"

  #project_id = "${var.project_name}"
  project_id = "${data.terraform_remote_state.org_setup.project_id}"
  name       = "${var.sql_name}"

  #tier = "${var.tier}"
  #availability_type = "${var.availability_type}"
  #backup_enabled = "${var.backup_enabled}"
  #backup_start_time = "${var.backup_start_time}"
  #disk_autoresize = "${var.disk_autoresize}"
  #disk_size = "${var.disk_size}"
  #disk_type = "${var.disk_type}"
  #maintenance_window_day = "${var.maintenance_window_day}"
  #maintenance_window_hour = "${var.maintenance_window_hour}"
  #maintenance_window_update_track = "${var.maintenance_window_update_track}"
  #user_labels = "${var.user_labels}"
  #ipv4_enabled = "${var.ipv4_enabled}"
  network = "${data.terraform_remote_state.project_setup.network_id_commons001-dev_private}"

  #activation_policy = "${var.activation_policy}"

  db_name = "${var.db_name}"

  #user_name = "${var.user_name}"
  #user_host = "${var.user_host}"
  #user_password = "${var.user_password}"  

  #global_address_name = "${var.global_address_name}"
  #global_address_purpose = "${var.global_address_purpose}"
  #global_address_type = "${var.global_address_type}"
  #global_address_prefix = "${var.global_address_prefix}"
}

/**********************************************
*      Create GKE commons001-gke
**********************************************/
module "commons001-gke" {
  source       = "../../../modules/gke"
  project      = "${data.terraform_remote_state.org_setup.project_id}"
  region       = "${var.cluster_region}"
  cluster_name = "${var.cluster_name}"
  node_name    = "${var.node_name}"
  network      = "${data.terraform_remote_state.project_setup.network_name_commons001-dev_private}"

  #  username               = "${var.username}"
  #  password               = "${var.password}"
  environment = "${var.env}"

  master_ipv4_cidr_block        = "${var.master_ipv4_cidr_block}"
  cluster_secondary_range_name  = "${var.cluster_secondary_range_name}"
  services_secondary_range_name = "${var.services_secondary_range_name}"
  subnetwork_name               = "${data.terraform_remote_state.project_setup.network_subnetwork_commons001-dev_private}"
  node_labels                   = "${var.node_labels}"
  node_tags                     = "${var.node_tags}"
  master_version                = "${var.min_master_version}"
}

/************************************************************************************************
*        Create Firewall Rules for Google Private Access for Health Checks/Master Access
************************************************************************************************/
module "commons001-gke-priv-access" {
  source                           = "../../../modules/firewall-gke-priv"
  project_id                       = "${data.terraform_remote_state.org_setup.project_id}"
  network_name                     = "${var.network_name}"
  fw_rule_deny_all_egress          = "${var.fw_rule_deny_all_egress}"
  fw_rule_allow_hc_ingress         = "${var.fw_rule_allow_hc_ingress}"
  fw_rule_allow_hc_egress          = "${var.fw_rule_allow_hc_egress}"
  fw_rule_allow_google_apis_egress = "${var.fw_rule_allow_google_apis_egress}"
  fw_rule_allow_master_node_egress = "${var.fw_rule_allow_master_node_egress}"
}
