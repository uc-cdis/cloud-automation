# -----------------
# Private Cloud SQL requires a VPC peer to a
# host GCP project
# -----------------

data "google_compute_network" "network" {
  provider = "google-beta"
  project  = "${var.project_id}"
  name     = "${var.network}"
}

# ------------------------
# Enable necessary service
# ------------------------
resource "google_project_service" "servicenetworking" {
  project            = "${var.project_id}"
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = "true"
}

# -------------------
# Create Global IP address
# ------------------

resource "google_compute_global_address" "private_ip_address" {
  provider = "google-beta"

  project       = "${var.project_id}"
  name          = "${var.global_address_name}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = "${data.google_compute_network.network.self_link}"
}

# --------------------
# Create Service Network Connection
# --------------------
resource "google_service_networking_connection" "private_vpc_connection" {
  provider = "google-beta"

  network                 = "${data.google_compute_network.network.self_link}"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = ["${google_compute_global_address.private_ip_address.name}"]
}

# -------------------
# Create Managed SQL Instance
# -------------------

resource "google_sql_database_instance" "instance" {
  provider = "google-beta"

  project          = "${var.project_id}"
  name             = "${var.name}"
  region           = "${var.region}"
  database_version = "${var.database_version}"

  depends_on = [
    "google_service_networking_connection.private_vpc_connection",
  ]

  settings {
    tier = "${var.tier}"

    ip_configuration {
      ipv4_enabled        = "${var.ipv4_enabled ? 1 : 0}"
      private_network     = "${data.google_compute_network.network.self_link}"
      #authorized_networks = "${var.authorized_networks}"
    }

    activation_policy = "${var.activation_policy}"
    availability_type = "${var.availability_type}"
    disk_autoresize   = "${var.disk_autoresize}"
    disk_size         = "${var.disk_size}"
    disk_type         = "${var.disk_type}"
    user_labels       = "${var.user_labels}"

    backup_configuration {
      binary_log_enabled = "${var.database_version == "POSTGRES_9_6" ? 0 : 1}"
      enabled            = "${var.backup_enabled}"
      start_time         = "${var.backup_start_time}"
    }

    maintenance_window {
      day          = "${var.maintenance_window_day}"
      hour         = "${var.maintenance_window_hour}"
      update_track = "${var.maintenance_window_update_track}"
    }
  }
}

# --------------------
# Create database
# --------------------
resource "google_sql_database" "default" {
  count = "${length(var.db_name)}"

  name     = "${element(var.db_name, count.index)}"
  project  = "${var.project_id}"
  instance = "${google_sql_database_instance.instance.name}"

  # charset    = "${var.db_charset}"
  # collation  = "${var.db_collation}"
  depends_on = ["google_sql_database_instance.instance"]
}

# -------------------
# Define User Account
# -------------------
resource "google_sql_user" "default" {
  name       = "${var.user_name}"
  project    = "${var.project_id}"
  instance   = "${google_sql_database_instance.instance.name}"
  host       = "${var.database_version == "POSTGRES_9_6" ? "" : var.user_host}"
  password   = "${var.user_password == "" ? random_id.user-password.hex : var.user_password}"
  depends_on = ["google_sql_database_instance.instance"]
}

# -------------------
# Generate password
# -------------------
resource "random_id" "user-password" {
  keepers = {
    name = "${google_sql_database_instance.instance.name}"
  }

  byte_length = 8
  depends_on  = ["google_sql_database_instance.instance"]
}
