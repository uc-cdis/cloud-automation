variable "project" {
  description = "The ID of the project in which the resource belongs."
}

variable "environment" {}
variable "cluster_name" {}
variable "node_name" {}

variable "region" {
  description = "The region that the cluster master and nodes should be created in."
}

#variable "username" {}
#variable "password" {}

variable "network" {}

variable "initial_node_count" {
  description = "The number of nodes to create in this cluster"
}

variable "daily_maintenance_window" {
  description = "Time window specified for daily maintenance operations. Format HH:MM"
}

variable "prod_machine_type" {
  description = "The name of a Google Compute Engine machine type. Defaults to n1-standard-1. To create a custom machine type"
}

variable "dev_machine_type" {
  description = "The name of a Google Compute Engine machine type. Defaults to n1-standard-1. To create a custom machine type"
}

variable "disk_type" {
  description = "Type of disk attached to each node, pd-ssd or pd-standard"
}

variable "disk_size_gb" {
  description = "Size of the disk attached to each node, specified in GB. The smallest allowed disk size is 10GB. Defaults to 100GB"
}

variable "min_node_cout" {
  description = "Minimum number of nodes in the NodePool"
}

variable "max_node_count" {
  description = "Maximum number of nodes in the NodePool."
}

variable "master_version" {
  description = "The current version of the master in the cluster. "
}

variable "cluster_secondary_range_name" {
  description = ""
}

variable "services_secondary_range_name" {
  description = ""
}

variable "master_ipv4_cidr_block" {
  description = "The IP range in CIDR notation to use for the hosted master network"
}

variable "default_node_pool" {
  description = " Deletes the default node pool upon cluster creation."
}

variable "network_policy" {
  description = "Whether network policy is enabled on the cluster."
}

// Kubernetes Addons
variable "horizontal_pod_autoscaling" {
  description = "Enable horizontal pod autoscaling addon"
}

variable "http_load_balancing" {
  description = "The status of the HTTP (L7) load balancing controller addon, which makes it easy to set up HTTP load balancers for services in a cluster."
}

variable "network_policy_config" {
  description = "Enable network policy addon"
}

variable "kubernetes_dashboard" {
  description = "Enable HTTP Load balancer addon"
}

// Private Cluster Config
variable "enable_private_endpoint" {
  description = "Whether the master's internal IP address is used as the cluster endpoint"
}

variable "enable_private_nodes" {
  description = ""
}

// IP Allocation Config
variable "use_ip_aliases" {
  description = ""
}

variable "create_subnetwork" {
  description = ""
}

variable "subnetwork_name" {
  description = "Name of the subnetwork in VPC."
}

variable "node_ipv4_cidr_block" {
  description = ""
}

variable "cluster_ipv4_cidr_block" {
  description = ""
}

variable "services_ipv4_cidr_block" {
  description = ""
}

// Master Authorized Networks
variable "master_authorized_network_name" {
  description = "Field for users to identify CIDR blocks"
}

variable "master_authorized_cidr_block" {
  description = "External network that can access Kubernetes master through HTTPS. Must be specified in CIDR notation"
}

// NODE POOL //
// Management
variable "node_auto_repair" {
  description = "Whether the nodes will be automatically repaired."
}

variable "node_auto_upgrade" {
  description = "Whether the nodes will be automatically upgraded"
}

variable "preemptible" {
  description = "whether or not the underlying node VMs are preemptible"
}

variable "node_tags" {
  description = "The list of instance tags applied to all nodes. "
  type        = "list"
}

variable "node_labels" {
  description = "The GCE resource labels (a map of key/value pairs) to be applied to the cluster"
  type        = "map"
}

variable "oauth_scopes" {
  type = "list"
  description = "oauth scopes for node and cluster configs"
}

variable "image_type" {
  description = "The image to  build the node pool from"
  default = "COS"
}
