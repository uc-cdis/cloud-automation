/***********************************
*      Create Cloud SQL commons
**********************************************/
module "sql" {
  source = "../../../modules/sql"

  #project_id = "${var.project_name}"
  project_id = "${data.terraform_remote_state.org_setup.project_id}"
  name       = "${var.sql_name}"
  region           = "${var.region}"

  database_version = "${var.database_version}"
  tier = "${var.db_instance_tier}"
  availability_type = "${var.availability_type}"
  backup_enabled = "${var.backup_enabled}"
  backup_start_time = "${var.backup_start_time}"
  disk_autoresize = "${var.db_disk_autoresize}"
  disk_size = "${var.db_disk_size}"
  disk_type = "${var.db_disk_type}"
  maintenance_window_day = "${var.db_maintenance_window_day}"
  maintenance_window_hour = "${var.db_maintenance_window_hour}"
  maintenance_window_update_track = "${var.db_maintenance_window_update_track}"
  user_labels = "${var.db_user_labels}"
  ipv4_enabled = "${var.ipv4_enabled}"
  network = "${data.terraform_remote_state.project_setup.network_id_commons_private}"

  activation_policy = "${var.activation_policy}"

  db_name = "${var.db_name}"

  user_name = "${var.db_user_name}"
  user_host = "${var.db_user_host}"
  user_password = "${var.db_user_password}"  

  global_address_name = "${var.global_address_name}"
  global_address_purpose = "${var.global_address_purpose}"
  global_address_type = "${var.global_address_type}"
  global_address_prefix = "${var.global_address_prefix}"
}

/**********************************************
*      Create GKE commons-gke
**********************************************/

module "commons-gke" {
  source       = "../../../modules/gke"
  project      = "${data.terraform_remote_state.org_setup.project_id}"
  region       = "${var.cluster_region}"
  cluster_name = "${var.cluster_name}"
  node_name    = "${var.node_name}"
  network      = "${data.terraform_remote_state.project_setup.network_name_commons_private}"

  #  username               = "${var.username}"
  #  password               = "${var.password}"
  environment = "${var.env}"
  create_subnetwork             = false
  master_ipv4_cidr_block        = "${var.master_ipv4_cidr_block}"
  cluster_secondary_range_name  = "${var.cluster_secondary_range_name}"
  services_secondary_range_name = "${var.services_secondary_range_name}"
  subnetwork_name               = "${element(data.terraform_remote_state.project_setup.subnetwork_name__commons_private, 0)}"
  node_labels                   = "${var.node_labels}"
  node_tags                     = "${var.node_tags}"
  master_version                = "${var.min_master_version}"
  master_authorized_network_name = "${var.master_authorized_network_name}"
#  master_authorized_cidr_block = "${var.master_authorized_cidr_block}"
  master_authorized_cidr_block  = "${data.terraform_remote_state.csoc_project_setup.cloud_nat_external_ip.0}/32"  # "${var.master_authorized_cidr_block}"
  use_ip_aliases = "${var.use_ip_aliases}"
  enable_private_endpoint	= "${var.enable_private_endpoint}"	

  node_ipv4_cidr_block = "${var.node_ipv4_cidr_block}"
  initial_node_count = "${var.initial_node_count}"
  min_node_cout = "${var.min_node_cout}"		
  max_node_count = "${var.max_node_count}"
  default_node_pool = "${var.default_node_pool}"
  enable_private_nodes = "${var.enable_private_nodes}"
  preemptible = "${var.preemptible}"
  image_type = "${var.image_type}"
  node_auto_upgrade = "${var.node_auto_upgrade}"
  prod_machine_type = "${var.prod_machine_type}"		
  dev_machine_type = "${var.dev_machine_type}"		
  node_auto_repair = "${var.node_auto_repair}"
  network_policy = "${var.network_policy}"	
  daily_maintenance_window = "${var.daily_maintenance_window}"
  kubernetes_dashboard = "${var.kubernetes_dashboard}"
  cluster_ipv4_cidr_block	= "${var.cluster_ipv4_cidr_block}"
  services_ipv4_cidr_block = "${var.services_ipv4_cidr_block}"
  horizontal_pod_autoscaling = "${var.horizontal_pod_autoscaling}"
  http_load_balancing	= "${var.http_load_balancing}"
  network_policy_config = "${var.network_policy_config}"
  disk_type = "${var.disk_type}"
  disk_size_gb = "${var.disk_size_gb}"
  oauth_scopes = ["${var.scopes}"]			
}
/************************************************************************************************
*        Create Firewall Rules for Google Private Access for Health Checks/Master Access
************************************************************************************************/

module "commons-gke-priv-access" {
  source                           = "../../../modules/firewall-gke-priv"
  project_id                       = "${data.terraform_remote_state.org_setup.project_id}"
  network_name                     = "${var.network_name}"
  fw_rule_deny_all_egress          = "${var.fw_rule_deny_all_egress}"
  fw_rule_allow_hc_ingress         = "${var.fw_rule_allow_hc_ingress}"
  fw_rule_allow_hc_egress          = "${var.fw_rule_allow_hc_egress}"
  fw_rule_allow_google_apis_egress = "${var.fw_rule_allow_google_apis_egress}"
  fw_rule_allow_master_node_egress = "${var.fw_rule_allow_master_node_egress}"
}

