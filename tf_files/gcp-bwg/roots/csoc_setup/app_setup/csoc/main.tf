terraform {
  # Specify terraform code version
  required_version = ">=0.11.7"

  # Specify Google provider version
  required_providers = {
    gcp = ">=2.1.0"
  }
}

provider "google" {
  credentials = "${file("../${var.credential_file}")}"
  region      = "${var.region}"
}

provider "google-beta" {
  credentials = "${file("../${var.credential_file}")}"
  region      = "${var.region}"
}

# CSOC
# public name = pub-ingress
# private name = csoc-inside01

module firewall-inbound-openvpn {
  source         = "../modules/firewall"
  enable_logging = "true"
  priority       = "1000"
  project_id     = "csoc-security-prorelativity"
  direction      = "INGRESS"
  name           = "csoc-inbound-openvpn"
  network        = "csoc-internal-network-pub-ingress"
  protocol       = "tcp"
  ports          = ["443", "1194"]
  source_ranges  = ["0.0.0.0/0"]
  target_tags    = ["openvpn"]
}

module firewall-inbound-gen3 {
  source         = "../modules/firewall"
  enable_logging = "true"
  priority       = "1010"
  project_id     = "csoc-security-prorelativity"
  direction      = "INGRESS"
  name           = "csoc-inbound-cloud-load-balancer"
  network        = "csoc-internal-network-pub-ingress"
  protocol       = "tcp"
  ports          = ["443"]
  source_ranges  = ["172.21.1.0/24"]
  target_tags    = ["cloud-load-balancer"]
}

module firewall-inbound-commons-gke {
  source         = "../modules/firewall"
  enable_logging = "true"
  priority       = "1010"
  project_id     = "csoc-security-prorelativity"
  direction      = "INGRESS"
  name           = "csoc-inbound-commons-gke"
  network        = "csoc-internal-network-pub-ingress"
  protocol       = "tcp"
  ports          = ["22"]
  source_ranges  = ["172.21.1.0/24"]
  target_tags    = ["commons-gke"]
}

# Qualys Scan Ingress UDP
module firewall-inbound-qualys-scan-udp {
  source         = "../modules/firewall"
  enable_logging = "true"
  priority       = "1010"
  project_id     = "csoc-security-prorelativity"
  direction      = "INGRESS"
  name           = "csoc-inbound-qualys-scan-udp"
  network        = "csoc-internal-network-pub-ingress"
  protocol       = "udp"
  ports          = ["0-65535"]
  source_ranges  = ["172.21.1.0/24"]
  target_tags    = ["commons-gke"]
}

# Qualys Scan Ingress TCP

module firewall-inbound-qualys-scan-tcp {
  source         = "../modules/firewall"
  enable_logging = "true"
  priority       = "1010"
  project_id     = "csoc-security-prorelativity"
  direction      = "INGRESS"
  name           = "csoc-inbound-qualys-scan-tcp"
  network        = "csoc-internal-network-pub-ingress"
  protocol       = "tcp"
  ports          = ["0-65535"]
  source_ranges  = ["172.21.1.0/24"]
  target_tags    = ["commons-gke"]
}

/**************
 EGRESS Firewall Rules
 *************/


# Qualys Scan Egress UDP
/*
module firewall-outbound-qualys-scan-udp {
  source = "../modules/firewall"  
  enable_logging = "true"
  priority = "1010"
  project_id = "csoc-security-prorelativity"
  direction = "EGRESS"
  name = "csoc-outbound-qualys-scan-udp"
  network = "csoc-internal-network-pub-ingress"
  protocol = "udp"
  ports = ["0-65535"]
  source_ranges = [""]
  target_tags = ["0.0.0.0/0"]
}

# Qualys Scan Egress TCP
module firewall-outbound-qualys-scan-tcp {
  source = "../modules/firewall"  
  enable_logging = "true"
  priority = "1010"
  project_id = "csoc-security-prorelativity"
  direction = "EGRESS"
  name = "csoc-outbound-qualys-scan-tcp"
  network = "csoc-internal-network-pub-ingress"
  protocol = "tcp"
  ports = ["0-65535"]
  source_ranges = [""]
  target_tags = ["0.0.0.0/0"]
}
*/

