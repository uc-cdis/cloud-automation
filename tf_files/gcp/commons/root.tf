// Configure the Google Cloud provider
provider "google" {
  region = "us-central1"
}

module "cdis_vpc" {
  source     = "../modules/vpc"
  gcp_region = "${var.gcp_region}"
  vpc_name   = "${var.vpc_name}"
  vpc_octet2 = "${var.vpc_octet2}"
  vpc_octet3 = "${var.vpc_octet3}"
}

module "k8s" {
  source        = "../modules/gke"
  gcp_region    = "${var.gcp_region}"
  cluster_name  = "${var.vpc_name}"
  cluster_index = "${var.cluster_index}"
  vpc_octet2    = "${var.vpc_octet2}"
  vpc_octet3    = "${var.vpc_octet3}"

  node_subnetwork = "${module.cdis_vpc.subnet_region1_name}"
  vpc_self_link   = "${module.cdis_vpc.vpc_self_link}"

  k8s_master_password       = "${var.k8s_master_password}"
  k8s_node_service_account  = "${var.k8s_node_service_account}"
  admin_box_service_account = "${var.admin_box_service_account}"
}

module "sql_dbs" {
  source                = "../modules/commons_sql"
  gcp_region            = "${var.gcp_region}"
  db_fence_password     = "${var.db_fence_password}"
  db_indexd_password    = "${var.db_indexd_password}"
  db_peregrine_password = "${var.db_peregrine_password}"
  db_sheepdog_password  = "${var.db_sheepdog_password}"
  vpc_name              = "${var.vpc_name}"
  authorized_cidr       = "${module.k8s.admin_box_nat_ip}/32"
}

module "config_files" {
  source                 = "../../shared/modules/k8s_configs"
  vpc_name               = "${var.vpc_name}"
  db_fence_address       = "${module.sql_dbs.fence_db_ip}"
  db_fence_password      = "${var.db_fence_password}"
  db_gdcapi_address      = "${module.sql_dbs.sheepdog_db_ip}"
  db_peregrine_password  = "${var.db_peregrine_password}"
  db_sheepdog_password   = "${var.db_sheepdog_password}"
  db_indexd_password     = "${var.db_indexd_password}"
  db_indexd_address      = "${module.sql_dbs.indexd_db_ip}"
  hostname               = "${var.hostname}"
  google_client_secret   = "${var.google_client_secret}"
  google_client_id       = "${var.google_client_id}"
  gdcapi_secret_key      = "${var.gdcapi_secret_key}"
  gdcapi_indexd_password = "${var.gdcapi_indexd_password}"
  kube_bucket_name       = "TBD"
  logs_bucket_name       = "TBD"
  dictionary_url         = "${var.dictionary_url}"
  portal_app             = "${var.portal_app}"
  config_folder          = "${var.config_folder}"
  ssl_certificate_id     = "GCP"
  aws_user_key           = "es AWS key - ignore"
  aws_user_key_id        = "es AWS key - ignore"
  indexd_prefix          = "add later"
  mailgun_api_key        = "ignore for now"
}
