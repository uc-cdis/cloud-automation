variable "project" {
  description = "The ID of the project in which the resource belongs."
}

variable "environment" {}
variable "cluster_name" {}
variable "node_name" {}

variable "region" {
  description = "The region that the cluster master and nodes should be created in."
}

variable "username" {}
variable "password" {}

variable "network" {}

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

variable "min_node_cout" {
  default     = "1"
  description = "Minimum number of nodes in the NodePool"
}

variable "max_node_count" {
  default     = "3"
  description = "Maximum number of nodes in the NodePool."
}

variable "master_version" {
  description = "The current version of the master in the cluster. "
  default     = "1.12.6-gke.7"
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
  default     = "10.0.0.0/28"
}

variable "default_node_pool" {
  description = " Deletes the default node pool upon cluster creation."
  default     = "true"
}

variable "network_policy" {
  description = "Whether network policy is enabled on the cluster."
  default     = "true"
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
  description = "Whether the master's internal IP address is used as the cluster endpoint"
  default     = true
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

variable "create_subnetwork" {
  description = ""
  default     = true
}

variable "subnetwork_name" {
  description = "Name of the subnetwork in VPC."
}

variable "node_ipv4_cidr_block" {
  description = ""
  default     = "172.28.28.0/24"
}

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
  default     = "csoc-network"
  description = "Field for users to identify CIDR blocks"
}

variable "master_authorized_cidr_block" {
  default = "172.21.1.0/24"

  #default = "127.0.0.1/32"
  description = "External network that can access Kubernetes master through HTTPS. Must be specified in CIDR notation"
}

// NODE POOL //
// Management
variable "node_auto_repair" {
  description = "Whether the nodes will be automatically repaired."
  default     = "true"
}

variable "node_auto_upgrade" {
  description = "Whether the nodes will be automatically upgraded"
  default     = "true"
}

variable "preemptible" {
  description = "whether or not the underlying node VMs are preemptible"
  default     = "false"
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
