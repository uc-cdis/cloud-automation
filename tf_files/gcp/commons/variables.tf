// for tagging resources ...
variable "vpc_name" {
  //default = "Commons1"
}

variable "hostname" {}

variable "vpc_octet2" {
  //default = 24
}

variable "vpc_octet3" {
  //default = 17
}

variable "gcp_region" {
  default = "us-central1"
}

variable "gdcapi_secret_key" {
  # FLASK_SECRET_KEY thing - don't know why we have flask sessions
}

variable "gdcapi_indexd_password" {}

//
// if we run multiple k8s clusters in the same VPC,
// then give each one a unique index -
// affects the CIDR assigned to the master-node VPC
// for VPC peering
//
variable "cluster_index" {
  default = 0
}

// for 'admin' basic-auth
variable "k8s_master_password" {}

// email addr of service-account to associate with each k8s node
variable "k8s_node_service_account" {}

// email addr of service-account to associate with the admin box
variable "admin_box_service_account" {}

variable "db_fence_password" {}

variable "db_sheepdog_password" {}

variable "db_peregrine_password" {}

variable "db_indexd_password" {}

variable "google_client_id" {
  # OAUTH client id for Google - allows "Login with Google"
}

variable "google_client_secret" {}

variable "dictionary_url" {
  # ex: https://s3.amazonaws.com/dictionary-artifacts/datadictionary/develop/schema.json
}

variable "portal_app" {
  # configuration key for data-portal - ex: dev, bloodpac, ...  #
}

variable "config_folder" {
  # Object folder of user.yaml file - ex: s3://cdis-gen3-users/${config_folder}/user.yaml
}
