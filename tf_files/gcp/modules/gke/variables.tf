//
// for tagging resources ...
// should normally just be the vpc_name
// of the VPC where the cluster is deployed,
// but may be different if a VPC has
// multiple k8s clusters - which we should avoid :-p
//
variable "cluster_name" {
  //default = "Commons1"
}

//
// if we run multiple k8s clusters in the same VPC,
// then give each one a unique index -
// affects the CIDR assigned to the master-node VPC
// for VPC peering
//
variable "cluster_index" {
  default = 0
}

variable "vpc_octet2" {
  //default = 24
}

variable "vpc_octet3" {
  //default = 17
}

variable "gcp_region" {}

// name of the subnetwork to stuff nodes into
variable "node_subnetwork" {}

// vpc self link
variable "vpc_self_link" {}

// basic-auth password for `admin` user on master node
variable "k8s_master_password" {}

// email addr of service-account to associate with each k8s node
variable "k8s_node_service_account" {}

// email addr of service-account to associate with the admin box
variable "admin_box_service_account" {}
