data "google_compute_zones" "available" {}

resource "google_container_cluster" "primary" {
  name                   = "${var.cluster_name}"
  zone                   = "${data.google_compute_zones.available.names[0]}"
  initial_node_count     = 3
  network                = "${var.vpc_self_link}"
  subnetwork             = "${var.node_subnetwork}"
  private_cluster        = true
  master_ipv4_cidr_block = "172.${var.vpc_octet2}.${var.vpc_octet3+0}.${var.cluster_index+16}/28"

  master_authorized_networks_config = {
    cidr_blocks = [
      {
        display_name = "internal"
        cidr_block   = "${google_compute_instance.admin_box.network_interface.0.access_config.0.assigned_nat_ip}/32"
      },
    ]
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "k8s-pods"
    services_secondary_range_name = "k8s-services"
  }

  # 
  # Not sure how to use this block - ugh
  #
  #network_policy         = {
  #  provider = ""
  #  enabled = true
  #}

  additional_zones = [
    "${data.google_compute_zones.available.names[1]}",
  ]
  maintenance_policy {
    daily_maintenance_window {
      start_time = "07:00"
    }
  }
  master_auth {
    username = "admin"
    password = "${var.k8s_master_password}"
  }
  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels {
      environment = "${var.cluster_name}"
    }

    machine_type = "n1-standard-1"

    service_account = "${var.k8s_node_service_account}"
    tags            = ["gen3", "k8s-node", "${var.cluster_name}"]
  }
}

// let's spin up an adminvm in the subnet too ...
// also serves as NAT gateway for now
resource "google_compute_instance" "admin_box" {
  name                      = "${var.cluster_name}-admin"
  machine_type              = "n1-standard-1"
  zone                      = "${data.google_compute_zones.available.names[0]}"
  allow_stopping_for_update = true
  can_ip_forward            = true

  tags = ["gen3", "k8s-admin", "${var.cluster_name}"]

  boot_disk {
    initialize_params {
      image = "ubuntu-1604-xenial-v20180509"
    }
  }

  // Local SSD disk
  scratch_disk {}

  network_interface {
    subnetwork = "${var.node_subnetwork}"

    access_config {
      // Ephemeral IP
    }
  }

  metadata {
    startup-script = <<EOF
#!/bin/bash -xe
#
# from 
#    https://github.com/GoogleCloudPlatform/terraform-google-nat-gateway/blob/master/main.tf
# , but simplified
#
# Enable ip forwarding and nat
sysctl -w net.ipv4.ip_forward=1
# Make forwarding persistent.
sed -i= 's/^[# ]*net.ipv4.ip_forward=[[:digit:]]/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
ethernet=$(ifconfig -s | grep -e ^e | awk '{ print $1 }' | head -1)
iptables -t nat -A POSTROUTING -o "$ethernet" -j MASQUERADE
EOF
  }

  service_account {
    #scopes = ["userinfo-email", "compute-ro", "storage-ro"]
    email  = "${var.admin_box_service_account}"
    scopes = ["cloud-platform"]
  }
}

#
# Route to internet through NAT gateway vm
#
resource "google_compute_route" "k8s_nat" {
  name                   = "${var.cluster_name}-k8s-nat"
  dest_range             = "0.0.0.0/0"
  network                = "${var.vpc_self_link}"
  next_hop_instance      = "${google_compute_instance.admin_box.name}"
  next_hop_instance_zone = "${google_compute_instance.admin_box.zone}"
  priority               = 900
  tags                   = ["k8s-node"]
}
