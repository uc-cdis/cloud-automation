// DATA Variables for Network and Subnetwork
data "google_compute_network" "compute_network" {
  name    = "${var.network}"
  project = "${var.project}"
}

data "google_compute_subnetwork" "compute_subnetwork" {
  name    = "${var.subnetwork_name}"
  project = "${var.project}"
}

# --------------------------------------------------
# CREATE A REGIONAL GKE PRIVATE CLUSTER
# --------------------------------------------------

resource "google_container_cluster" "primary" {
  provider = "google-beta"
  project  = "${var.project}"
  name     = "${var.cluster_name}"
  location = "${var.region}"

  network                  = "${data.google_compute_network.compute_network.self_link}"
  subnetwork               = "${data.google_compute_subnetwork.compute_subnetwork.self_link}"
  remove_default_node_pool = "${var.default_node_pool}"
  initial_node_count       = "${var.initial_node_count}"

  # Private Cluster
  # master ipv4 must be /28 and cannot overlap with any subnetwork in VPC network
  private_cluster_config {
    enable_private_endpoint = "${var.enable_private_endpoint}"
    enable_private_nodes    = "${var.enable_private_nodes}"
    master_ipv4_cidr_block  = "${var.master_ipv4_cidr_block}"
  }

  ip_allocation_policy {
    use_ip_aliases = "${var.use_ip_aliases}"

    // Testing showed that these variables cannot be used if Subnetwork and Alias were already provisioned
    /*
   create_subnetwork = "${var.create_subnetwork}"
   subnetwork_name = "${var.subnetwork_name}"   
   node_ipv4_cidr_block = "${var.node_ipv4_cidr_block}"
   cluster_ipv4_cidr_block = "${var.cluster_ipv4_cidr_block}"
   services_ipv4_cidr_block = "${var.services_ipv4_cidr_block}"
  */

    // If subnetwork and alias are already created use the secondary range names below
    cluster_secondary_range_name  = "${var.cluster_secondary_range_name}"
    services_secondary_range_name = "${var.services_secondary_range_name}"
  }

  # Setting an empty username and password explicitly disables basic auth
  #master_auth {
  #  username = "${var.username}"
  #  password = "${var.password}"
  #}

  # Duration of the time windows for maintenance
  maintenance_policy {
    daily_maintenance_window {
      start_time = "${var.daily_maintenance_window}"
    }
  }

  logging_service    = "logging.googleapis.com"
  monitoring_service = "monitoring.googleapis.com"

  # Authorized Networks  
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "${var.master_authorized_cidr_block}"
      display_name = "${var.master_authorized_network_name}"
    }
  }

  min_master_version = "${var.master_version}"

  resource_labels = "${var.node_labels}"

  node_config {
    oauth_scopes = ["${var.oauth_scopes}"]

    tags = ["${var.node_tags}"]

    timeouts {
      create = "30m"
      update = "30m"
      delete = "30m"
    }
  }

  network_policy {
    enabled = "${var.network_policy ? 1 : 0}"
  }

  addons_config {
    http_load_balancing {
      disabled = "${var.http_load_balancing ? 0 : 1}"
    }

    horizontal_pod_autoscaling {
      disabled = "${var.horizontal_pod_autoscaling ? 0 : 1}"
    }

    network_policy_config {
      disabled = "${var.network_policy_config ? 0 : 1 }"
    }

    kubernetes_dashboard {
      disabled = "${var.kubernetes_dashboard ? 0 : 1}"
    }
  }
}

# --------------------------------------------------
# CREATE NODE POOL
# --------------------------------------------------
resource "google_container_node_pool" "node_pool" {
  provider   = "google-beta"
  name       = "${var.node_name}"
  location   = "${var.region}"
  project    = "${var.project}"
  cluster    = "${google_container_cluster.primary.name}"
  node_count = "${var.initial_node_count}"

  autoscaling {
    min_node_count = "${var.min_node_cout}"
    max_node_count = "${var.max_node_count}"
  }

  management {
    auto_repair  = "${var.node_auto_repair ? 1 : 0}"
    auto_upgrade = "${var.node_auto_upgrade ? 1 : 0}"
  }

  node_config {
    image_type = "${var.image_type}"
    labels     = "${var.node_labels}"

    #metadata = ""
    #taint = ""
    tags = ["${var.node_tags}"]
  
    disk_type = "${var.disk_type}"
    disk_size_gb = "${var.disk_size_gb}"

    preemptible  = "${var.preemptible}"
    machine_type = "${var.environment == "prod" ? var.prod_machine_type : var.dev_machine_type}"

    oauth_scopes =  ["${var.oauth_scopes}" ]
  }
}
