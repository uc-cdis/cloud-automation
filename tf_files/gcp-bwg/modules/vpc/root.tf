/******************************************
	VPC configuration
 *****************************************/
resource "google_compute_network" "network" {
  project                 = "${var.project_id}"
  name                    = "${var.network_name}"
  auto_create_subnetworks = "${var.auto_create_subnetworks}"
  routing_mode            = "${var.routing_mode}"  
  delete_default_routes_on_create = "${var.delete_default_routes}"
}

/******************************************
	Subnet with alias configuration
 *****************************************/

resource "google_compute_subnetwork" "subnetwork" {
  count = "${length(var.subnets) > 0 && var.create_vpc_secondary_ranges == true ? length(var.subnets):0}"
  name                     = "${lookup(var.subnets[count.index], "subnet_name")}"
  ip_cidr_range            = "${lookup(var.subnets[count.index], "subnet_ip")}"
  region                   = "${lookup(var.subnets[count.index], "subnet_region")}"
  private_ip_google_access = "${lookup(var.subnets[count.index], "subnet_private_access", "false")}"
  enable_flow_logs         = "${lookup(var.subnets[count.index], "subnet_flow_logs", "false")}"
  network                  = "${google_compute_network.network.name}"
  project                  = "${var.project_id}"
  enable_flow_logs         = "${var.subnet_flow_logs}"


  secondary_ip_range = "${var.secondary_ranges[lookup(var.subnets[count.index], "subnet_name")]}"
}
###########################END SUBNET ####################################################################

/******************************************
	Subnet no alias configuration
 *****************************************/

resource "google_compute_subnetwork" "subnetworknoalias" {
  count = "${length(var.subnets) > 0 && var.create_vpc_secondary_ranges == false ? 0:length(var.subnets)}"

  name                     = "${lookup(var.subnets[count.index], "subnet_name")}"
  ip_cidr_range            = "${lookup(var.subnets[count.index], "subnet_ip")}"
  region                   = "${lookup(var.subnets[count.index], "subnet_region")}"
  private_ip_google_access = "${lookup(var.subnets[count.index], "subnet_private_access", "false")}"
  enable_flow_logs         = "${lookup(var.subnets[count.index], "subnet_flow_logs", "false")}"
  network                  = "${google_compute_network.network.name}"
  project                  = "${var.project_id}"
  enable_flow_logs         = "${var.subnet_flow_logs}"


}
###########################END SUBNET ####################################################################
data "google_compute_subnetwork" "created_subnets" {
  count = "${length(var.subnets) > 0 && var.create_vpc_secondary_ranges == true ? length(var.subnets):0}"

  name    = "${element(google_compute_subnetwork.subnetwork.*.name, count.index)}"
  region  = "${element(google_compute_subnetwork.subnetwork.*.region, count.index)}"
  project = "${var.project_id}"
}
data "google_compute_subnetwork" "created_subnetsnoalias" {
  count = "${length(var.subnets) > 0 && var.create_vpc_secondary_ranges == false ? 0:length(var.subnets)}"

  name    = "${element(google_compute_subnetwork.subnetworknoalias.*.name, count.index)}"
  region  = "${element(google_compute_subnetwork.subnetworknoalias.*.region, count.index)}"
  project = "${var.project_id}"
}
