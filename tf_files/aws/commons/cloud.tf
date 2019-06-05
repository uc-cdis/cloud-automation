# Inject credentials via the AWS_PROFILE environment variable and shared credentials file
# and/or EC2 metadata service
terraform {
  backend "s3" {
    encrypt = "true"
  }
}

# Inject credentials via the AWS_PROFILE environment variable and shared credentials file and/or EC2 metadata service
#
provider "aws" {}

module "cdis_vpc" {
  ami_account_id                 = "${var.ami_account_id}"
  source                         = "../modules/vpc"
  #vpc_octet2                    = "${var.vpc_octet2}"
  #vpc_octet3                    = "${var.vpc_octet3}"
  vpc_cidr_block                 = "${var.vpc_cidr_block}"
  vpc_name                       = "${var.vpc_name}"
  ssh_key_name                   = "${aws_key_pair.automation_dev.key_name}"
  #csoc_cidr                     = "${var.csoc_cidr}"
  #peering_cidr                   = "${data.aws_vpc.csoc_vpc.cidr_block}" #"${var.peering_cidr}"
  peering_cidr                   = "${var.peering_cidr}"
  csoc_account_id                = "${var.csoc_account_id}"
  squid-nlb-endpointservice-name = "${var.squid-nlb-endpointservice-name}"
  organization_name              = "${var.organization_name}"

  csoc_managed                   = "${var.csoc_managed}"
  csoc_vpc_id                    = "${var.csoc_vpc_id}"
}

# logs bucket for elb logs
module "elb_logs" {
  source          = "../modules/s3-logs"
  log_bucket_name = "logs-${var.vpc_name}-gen3"
  environment     = "${var.vpc_name}"
}

module "config_files" {
  source                      = "../../shared/modules/k8s_configs"
  vpc_name                    = "${var.vpc_name}"
  db_fence_address            = "${aws_db_instance.db_fence.address}"
  db_fence_password           = "${var.db_password_fence}"
  db_fence_name               = "${aws_db_instance.db_fence.name}"
  db_gdcapi_address           = "${aws_db_instance.db_gdcapi.address}"
  db_gdcapi_username          = "${aws_db_instance.db_gdcapi.username}"

  # legacy commons have a separate "gdcapi" postgres user with its own password
  db_gdcapi_password          = "${var.db_password_gdcapi == "" ? var.db_password_sheepdog : var.db_password_gdcapi}"
  db_gdcapi_name              = "${aws_db_instance.db_gdcapi.name}"
  db_peregrine_password       = "${var.db_password_peregrine}"
  db_sheepdog_password        = "${var.db_password_sheepdog}"
  db_indexd_address           = "${aws_db_instance.db_indexd.address}"
  db_indexd_username          = "${aws_db_instance.db_indexd.username}"
  db_indexd_password          = "${var.db_password_indexd}"
  db_indexd_name              = "${aws_db_instance.db_indexd.name}"
  hostname                    = "${var.hostname}"
  google_client_secret        = "${var.google_client_secret}"
  google_client_id            = "${var.google_client_id}"
  hmac_encryption_key         = "${var.hmac_encryption_key}"
  gdcapi_secret_key           = "${var.gdcapi_secret_key}"
  gdcapi_indexd_password      = "${var.gdcapi_indexd_password}"
  gdcapi_oauth2_client_id     = "${var.gdcapi_oauth2_client_id}"
  gdcapi_oauth2_client_secret = "${var.gdcapi_oauth2_client_secret}"

  kube_bucket_name            = "${aws_s3_bucket.kube_bucket.id}"
  logs_bucket_name            = "${module.elb_logs.log_bucket_name}"
  dictionary_url              = "${var.dictionary_url}"
  portal_app                  = "${var.portal_app}"
  config_folder               = "${var.config_folder}"

  ssl_certificate_id          = "${var.aws_cert_name}"

  aws_user_key                = "${module.cdis_vpc.es_user_key}"
  aws_user_key_id             = "${module.cdis_vpc.es_user_key_id}"

  indexd_prefix               = "${var.indexd_prefix}"

## mailgun creds
  mailgun_api_key             = "${var.mailgun_api_key}"
  mailgun_api_url             = "${var.mailgun_api_url}"
  mailgun_smtp_host           = "${var.mailgun_smtp_host}"

}

module "cdis_alarms" {
  source                      = "../modules/commons-alarms"
  slack_webhook               = "${var.slack_webhook}"
  secondary_slack_webhook     = "${var.secondary_slack_webhook}"
  vpc_name                    = "${var.vpc_name}"
  alarm_threshold             = "${var.alarm_threshold}"
  db_fence_size               = "${aws_db_instance.db_fence.allocated_storage}"
  db_indexd_size              = "${aws_db_instance.db_indexd.allocated_storage}"
  db_gdcapi_size              = "${aws_db_instance.db_gdcapi.allocated_storage}"
  db_fence                    = "${aws_db_instance.db_fence.identifier}"
  db_indexd                   = "${aws_db_instance.db_indexd.identifier}"
  db_gdcapi                   = "${aws_db_instance.db_gdcapi.identifier}"
}


resource "aws_vpc_endpoint" "k8s-s3" {
  vpc_id                      = "${module.cdis_vpc.vpc_id}"

  #service_name               = "com.amazonaws.us-east-1.s3"
  service_name                = "${data.aws_vpc_endpoint_service.s3.service_name}"
  route_table_ids             = ["${aws_route_table.private_kube.id}"]
}

resource "aws_route_table" "private_kube" {
  vpc_id                      = "${module.cdis_vpc.vpc_id}"

  route {
    cidr_block                = "0.0.0.0/0"
    instance_id               = "${module.cdis_vpc.proxy_id}"
  }

  route {
    # cloudwatch logs route
    cidr_block                = "54.224.0.0/12"
    nat_gateway_id            = "${module.cdis_vpc.nat_gw_id}"
  }

  route {
    #from the commons vpc to the csoc vpc via the peering connection
    #cidr_block                  = "${var.csoc_cidr}"
    #cidr_block                  = "${var.csoc_managed == "yes" ? var.peering_cidr : data.aws_vpc.csoc_vpc.cidr_block}"
    cidr_block                  = "${var.peering_cidr}"
    vpc_peering_connection_id   = "${module.cdis_vpc.vpc_peering_id}"
  }

  tags {
    Name                      = "private_kube"
    Environment               = "${var.vpc_name}"
    Organization              = "${var.organization_name}"
  }
}

resource "aws_route_table_association" "private_kube" {
  subnet_id                   = "${aws_subnet.private_kube.id}"
  route_table_id              = "${aws_route_table.private_kube.id}"
}

resource "aws_subnet" "private_kube" {
  vpc_id                      = "${module.cdis_vpc.vpc_id}"
  #cidr_block                  = "172.${var.vpc_octet2}.${var.vpc_octet3 + 2}.0/24"
  cidr_block                  = "${cidrsubnet(var.vpc_cidr_block,4,2)}"
  map_public_ip_on_launch     = false
  availability_zone           = "${data.aws_availability_zones.available.names[0]}"
  #tags                        = "${map("Name", "private_kube", "Organization", var.organization_name, "Environment", var.vpc_name, "kubernetes.io/cluster/${var.vpc_name}", "owned")}"
  tags                        = "${map("Name", "int_services", "Organization", var.organization_name, "Environment", var.vpc_name )}"

  lifecycle {
    # allow user to change tags interactively - ex - new kube-aws cluster
    ignore_changes = ["tags", "availability_zone"]
  }
}

#resource "aws_route_table_association" "public_kube" {
#  subnet_id      = "${aws_subnet.public_kube.id}"
#  route_table_id = "${module.cdis_vpc.public_route_table_id}"
#}

#resource "aws_subnet" "public_kube" {
#  vpc_id                  = "${module.cdis_vpc.vpc_id}"
#  cidr_block              = "172.${var.vpc_octet2}.${var.vpc_octet3 + 4}.0/24"
#  map_public_ip_on_launch = true
#  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  # Note: KubernetesCluster tag is required by kube-aws to identify the public subnet for ELBs
#  tags = "${map("Name", "public_kube", "Organization", ${var.organization_name}, "Environment", var.vpc_name, "kubernetes.io/cluster/${var.vpc_name}", "shared", "kubernetes.io/role/elb", "", "KubernetesCluster", "${local.cluster_name}")}"

#  lifecycle {
    # allow user to change tags interactively - ex - new kube-aws cluster
#    ignore_changes = ["tags", "availability_zone"]
#  }
#}

resource "aws_subnet" "private_db_alt" {
  vpc_id                      = "${module.cdis_vpc.vpc_id}"
  #cidr_block                  = "172.${var.vpc_octet2}.${var.vpc_octet3 + 3}.0/24"
  cidr_block                  = "${cidrsubnet(var.vpc_cidr_block,4,3)}"
  availability_zone           = "${data.aws_availability_zones.available.names[1]}"
  map_public_ip_on_launch     = false
  #availability_zone           = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name                      = "private_db_alt"
    Environment               = "${var.vpc_name}"
    Organization              = "${var.organization_name}"
  }

  lifecycle {
    # allow user to change tags interactively - ex - new kube-aws cluster
    ignore_changes = ["tags", "availability_zone"]
  }
}

resource "aws_db_subnet_group" "private_group" {
  name                        = "${var.vpc_name}_private_group"
  subnet_ids                  = ["${aws_subnet.private_kube.id}", "${aws_subnet.private_db_alt.id}"]

  tags {
    Name                      = "Private subnet group"
    Environment               = "${var.vpc_name}"
    Organization              = "${var.organization_name}"
  }

  description                 = "Private subnet group"
}


## This is for endpoint service needed to acccess the squid nlb in CSOC VPC. We need to add the subnets for both private_user and
# private_kube; hence have the code in here

resource "aws_vpc_endpoint" "squid-nlb" {
  count                      = "${var.csoc_managed == "yes" ? 1 : 0}"
  vpc_id                     = "${module.cdis_vpc.vpc_id}"
  service_name               = "${var.squid-nlb-endpointservice-name}"
  vpc_endpoint_type          = "Interface"

  # we need to supply it a subnet id ; so that it can create the dns name for the endpoint which is then added to the route53 for cloud-proxy
  #subnet_ids                 = ["${module.cdis_vpc.private_subnet_id}", "${aws_subnet.public_kube.id}"]
  subnet_ids                 = ["${aws_subnet.private_kube.id}"]
  private_dns_enabled        = false
  
  security_group_ids = [
     "${module.cdis_vpc.security_group_local_id}"
  ]
}


resource "aws_route53_record" "squid-nlb" {
  count                      = "${var.csoc_managed == "yes" ? 1 : 0}"
  zone_id                    = "${module.cdis_vpc.zone_id}"
  name                       = "csoc-cloud-proxy.${module.cdis_vpc.zone_name}"
  type                       = "CNAME"
  ttl                        = "300"
  records                    = ["${lookup(aws_vpc_endpoint.squid-nlb.dns_entry[0], "dns_name")}"]
}
