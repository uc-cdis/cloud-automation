variable "project_name" {}
variable "credential_file" {}
variable "region" {}
variable "env" {}

// Terraform State
variable "prefix_org_setup" {}

variable "prefix_project_setup" {}
variable "prefix_org_policies" {}
variable "state_bucket_name" {}
variable "prefix_platform_setup" {}
variable "state_bucket_name_csoc" {}

variable "tf_state_project_setup_csoc" {
  description = "The project_setup terraform state from the csoc."
}

variable "prefix_project_setup_csoc" {}

variable "prefix_org_setup_csoc" {
  description = "Terraform state folder name in the CSOC."
}

variable "tf_state_org_setup_csoc" {
  description = "Terraform state file name in the CSOC for Organization."
}

// Cloud SQL ################################################################
variable "sql_name" {
  description = "Name of the Cloud SQL instance."
  default     = ""
}

variable "cluster_region" {
  description = "The region that the cluster master and nodes should be created in."
  default     = "us-central1"
}

variable "global_address_name" {
  description = "Name of the global address resource."
  default     = "cloudsql-private-ip-address"
}

variable "global_address_purpose" {
  description = "The purpose of the resource.VPC_PEERING - for peer networks."
  default     = "VPC_PEERING"
}

variable "global_address_type" {
  description = "The type of the address to reserve. Use External or Internal. Default is Internal."
  default     = "INTERNAL"
}

variable "global_address_prefix" {
  description = "The prefix length of the IP range. Not applicable if address type=EXTERNAL."
  default     = "16"
}

#### Database Version Supports POSTGRES_9_6 or MySQL_5_7 or MySQL_5_6
variable "database_version" {
  description = "The database version to use. Supports POSTGRES_9_6 or MySQL_5_7 or MySQL_5_6"
  default     = "POSTGRES_9_6"
}

variable "db_instance_tier" {
  description = "The tier for the master instance.Postgres supports only shared-core machine types such as db-f1-micro for instance-level pricing, the rest is custom pricing by cpu and mem"
  default     = "db-f1-micro"
}

variable "availability_type" {
  description = "The availability type for the master instance.This is only used to set up high availability for the PostgreSQL instance. Can be either `ZONAL` or `REGIONAL`."
  default     = "ZONAL"
}

variable "backup_enabled" {
  description = "True if backup configuration is enabled."
  default     = "true"
}

variable "backup_start_time" {
  description = "HH:MM format time indicating when backup configuration starts."
  default     = "02:00"
}

variable "db_disk_autoresize" {
  description = "Configuration to increase storage size."
  default     = "true"
}

variable "db_disk_size" {
  description = "The disk size for the master instance."
  default     = "10"
}

variable "db_disk_type" {
  description = "The type of data disk: PD_SSD or PD_HDD."
  default     = "PD_SSD"
}

variable "db_maintenance_window_day" {
  description = "The day of week (1-7) for the master instance maintenance."
  default     = "7"
}

variable "db_maintenance_window_hour" {
  description = "The hour of day (0-23) maintenance window for the master instance maintenance."
  default     = "2"
}

variable "db_maintenance_window_update_track" {
  description = "The update track of maintenance window for the master instance maintenance.Can be either `canary` or `stable`."
  default     = "stable"
}

variable "db_user_labels" {
  description = "The key/value labels for the master instances."
  type        = "map"
  default     = {}
}

variable "ipv4_enabled" {
  description = "Whether this Cloud SQL instance should be assigned a public IPV4 address."
  default     = "false"
}

variable "db_network" {
  description = "Network name inside of the VPC."
  default     = "default"
}

variable "sql_network" {
  description = "Network name inside of the VPC."
  default     = "default"
}

/*
variable "db_authorized_networks" {
  description = "Allowed networks to connect to this sql instance."
  default     = []
}
*/
variable "activation_policy" {
  description = "This specifies when the instance should be active. Can be either ALWAYS, NEVER or ON_DEMAND."
  default     = "ALWAYS"
}

variable "db_name" {
  description = "The name of the default database to create"
  type        = "list"
  default     = []
}

variable "db_user_name" {
  description = "The name of the default user"
  default     = "postgres-user"
}

variable "db_user_host" {
  description = "The host for the default user.This is only supported for MySQL instances."
  default     = ""
}

variable "db_user_password" {
  description = "The password for the default user. If not set, a random one will be generated and available in the generated_user_password output variable."
  default     = ""
}

############# END SQL ########################################################

// GKE

variable "commons_private_subnet_secondary_name1" {
  description = "Network alias name for GKE services."
}

variable "commons_private_subnet_secondary_name2" {
  description = "Network alias name for GKE pods."
}

variable "egress_allow_proxy_name" {
  description = "Name for egress proxy"
}

variable "cluster_name" {
  description = "The name of the cluster, unique within the project and location."
}

variable "node_name" {
  description = "Name of the node pool."
}

variable "initial_node_count" {
  default     = "1"
  description = "The number of nodes to create in this cluster"
}

variable "daily_maintenance_window" {
  default     = "07:00"
  description = "Time window specified for daily maintenance operations. Format HH:MM"
}

variable "prod_machine_type" {
  default     = "n1-standard-1"
  description = "The name of a Google Compute Engine machine type. Defaults to n1-standard-1. To create a custom machine type"
}

variable "dev_machine_type" {
  default     = "g1-small"
  description = "The name of a Google Compute Engine machine type. Defaults to n1-standard-1. To create a custom machine type"
}

variable "disk_size_gb" {
  default     = "100"
  description = "Size of the disk attached to each node, specified in GB. The smallest allowed disk size is 10GB. Defaults to 100GB"
}

variable "disk_type" {
  description = "Type of disk attached to each node, pd-ssd or pd-standard"
  default     = "pd-standard"
}

variable "min_node_cout" {
  default     = "1"
  description = "Minimum number of nodes in the NodePool"
}

variable "max_node_count" {
  default     = "3"
  description = "Maximum number of nodes in the NodePool."
}

variable "min_master_version" {
  description = "The current version of the master in the cluster. "
}

variable "cluster_secondary_range_name" {
  description = ""
  default     = "kubernetes-pods"
}

variable "services_secondary_range_name" {
  description = ""
  default     = "kubernetes-services"
}

variable "master_ipv4_cidr_block" {
  description = "The IP range in CIDR notation to use for the hosted master network"
}

variable "default_node_pool" {
  description = " Deletes the default node pool upon cluster creation."
  default     = "true"
}

variable "network_policy" {
  description = "Whether network policy is enabled on the cluster."
  default     = "false"
}

// Kubernetes Addons
variable "horizontal_pod_autoscaling" {
  description = "Enable horizontal pod autoscaling addon"
  default     = true
}

variable "http_load_balancing" {
  description = "The status of the HTTP (L7) load balancing controller addon, which makes it easy to set up HTTP load balancers for services in a cluster."
  default     = true
}

variable "network_policy_config" {
  description = "Enable network policy addon"
  default     = true
}

variable "kubernetes_dashboard" {
  description = "Enable HTTP Load balancer addon"
  default     = false
}

// Private Cluster Config
variable "enable_private_endpoint" {
  description = "Whether the master's internal IP address is used as the cluster endpoint. Requires bastion host to be on directly adjacent vpc"
  default     = false
}

variable "enable_private_nodes" {
  description = ""
  default     = true
}

// IP Allocation Config
variable "use_ip_aliases" {
  description = ""
  default     = true
}

variable "node_ipv4_cidr_block" {
  description = ""
  default     = "172.28.28.0/24"
}

/*
variable "create_subnetwork" {
  description = ""
  default     = false
}

variable "subnetwork_name" {
  description = "Name of the subnetwork in VPC."
  type = "string"
}
*/

variable "cluster_ipv4_cidr_block" {
  description = ""
  default     = "10.56.0.0/14"
}

variable "services_ipv4_cidr_block" {
  description = ""
  default     = "10.170.80.0/20"
}

// Master Authorized Networks
variable "master_authorized_network_name" {
  description = "Field for users to identify CIDR blocks"
  default     = "csoc-network"
}

variable "master_authorized_cidr_block" {
  description = "External network that can access Kubernetes master through HTTPS. Must be specified in CIDR notation"
  default     = "172.29.29.0/24"
}

// NODE POOL //
// Management
variable "node_auto_repair" {
  description = "Whether the nodes will be automatically repaired."
  default     = "true"
}

variable "node_auto_upgrade" {
  description = "Whether the nodes will be automatically upgraded"
  default     = true
}

variable "preemptible" {
  description = "whether or not the underlying node VMs are preemptible"
  default     = false
}

variable "node_tags" {
  description = "The list of instance tags applied to all nodes. "
  type        = "list"
  default     = []
}

variable "node_labels" {
  description = "The GCE resource labels (a map of key/value pairs) to be applied to the cluster"
  type        = "map"
  default     = {}
}

variable "scopes" {
  description = "oauth scopes for node and cluster configs"
  description = "cluster service account rights"

  default = ["https://www.googleapis.com/auth/trace.append",
    "https://www.googleapis.com/auth/servicecontrol",
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/service.management.readonly",
  ]
}

variable "image_type" {
  description = "The image to  build the node pool from"
  default     = "COS"
}

########### Google Public Access Info#############################################

#variable "network_name" {
#  description = "The name of the VPC network being created"
#}

variable "fw_rule_deny_all_egress" {
  description = "Deny all egress traffic out of VPC"
}

variable "fw_rule_allow_hc_ingress" {
  description = "Allow ingress for health checks"
}

variable "fw_rule_allow_hc_egress" {
  description = "Allow egress to health checks"
}

variable "fw_rule_allow_google_apis_egress" {
  description = "Allow egress to Google APIs"
}

variable "fw_rule_allow_master_node_egress" {
  description = "Allow egress to master node subnet"
}

############# Add Firewall rules to CSOC Private #####################################

variable "csoc_private_egrees_gke_endpoint" {
  description = "Name of the firewall rule egress rule to be added to csoc private."
}

variable "csoc_private_ingress_gke_endpoint" {
  description = "Name of the firewall rule ingree rule to be added."
}

/*
variable "csoc_private_ingress_gke_endpoint" {
  description = "Name of the firewall rule ingress rule to be added to csoc private."
}
*/

