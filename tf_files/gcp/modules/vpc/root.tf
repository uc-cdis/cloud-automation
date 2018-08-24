// Just create a VPC with a subnet in one region
resource "google_compute_network" "vpc" {
  name                    = "${var.vpc_name}"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "region1" {
  name = "gen3-${var.vpc_name}-${var.gcp_region}"

  //
  // /20 block allocated for VPC - divide between subnets
  // /24 for each subnet - which leaves room for 2^4 = 16 subnets
  // except gke wants to peer with the VPC with a /28 VPC, so
  // we reserve subnect +0 for up to 16 gke private master peers
  //
  ip_cidr_range = "172.${var.vpc_octet2}.${var.vpc_octet3+1}.0/24"

  network                  = "${google_compute_network.vpc.self_link}"
  region                   = "${var.gcp_region}"
  private_ip_google_access = true

  // TODO - make this a variable ...
  secondary_ip_range = [
    {
      range_name    = "k8s-services"
      ip_cidr_range = "10.0.32.0/20"
    },
    {
      range_name    = "k8s-pods"
      ip_cidr_range = "10.4.0.0/14"
    },
  ]
}

resource "google_compute_firewall" "ssh" {
  name    = "${var.vpc_name}-ssh-from-everywhere"
  network = "${google_compute_network.vpc.name}"

  allow {
    protocol = "all"
  }

  source_ranges = ["172.${var.vpc_octet2}.${var.vpc_octet3}.0/20"]
}

resource "google_compute_firewall" "allow-internal" {
  name    = "${var.vpc_name}-allow-internal"
  network = "${google_compute_network.vpc.name}"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}
