# Could not get Private IP feature to work. This could be
# a beta option?
# https://github.com/terraform-providers/terraform-provider-google/issues/2127
# The IP config block is what's needed to make private

# Create Database Instance
/*
resource "google_sql_database_instance" "private-instance" {
    name = "${var.commons_sql_name}"
    region = "${var.instance_region}"
    database_version = "${var.postgresql_version}"
    project = "${var.project}"  
    settings {
        tier = "${var.tier}",
        availability_type = "${var.availability_type}",
        disk_size = "${var.disk_size}"
        /*
        ip_configuration {
            ipv4_enabled = "false"
            #private_network = "${var.private_ip_enabled}"
            private_network = "https://www.googleapis.com/compute/v1/projects/tf-deploy-1-6e1318de/global/networks/gen3-commons-us-central1"
        }   
            
    }
}

# Create Database
resource "google_sql_database" "default" {
  name = "default-db"
  project = "${var.project}"
  instance = "${google_sql_database_instance.private-instance.name}"
  depends_on = ["${google_sql_database_instance.private-instance.name}"]
}

# 2nd Gen instances include a default 'root'@'%' user with no password.
# This user is deleted by Terraform on instance creation. Need to create a
# sql user account

# Create SQL User Account
resource "random_id" "user-password" {
    keepers = {
        name = "${google_sql_database_instance.private-instance.name}"
    }
    byte_length = 8
    depends_on = ["${google_sql_database_instance.private-instance}"]
}
resource "google_sql_user" "default" {
  name = "me"
  project = "${var.project}"
  instance = "${google_sql_database_instance.private-instance.name}"
  host = "me.com"
    password   = "${var.user_password == "" ? random_id.user-password.hex : var.user_password}"
    depends_on = ["google_sql_database_instance.private-instance"]

}
*/

locals {
  default_user_host = ""

  #ip_configuration_enabled = "${length(keys(var.ip_configuration)) > 0 ? true : false}"

  #ip_configurations = {
  #  enabled  = "${list(var.ip_configuration)}"
  #  disabled = "${list()}"
  #}
}

resource "google_sql_database_instance" "default" {
  project          = "${var.project_id}"
  name             = "${var.name}"
  database_version = "${var.database_version}"
  region           = "${var.region}"

  settings {
    #activation_policy           = "${var.activation_policy}"    
    #authorized_gae_applications = ["${var.authorized_gae_applications}"]
    #backup_configuration        = ["${var.backup_configuration}"]
    #ip_configuration            = "${local.ip_configurations["${local.ip_configuration_enabled ? "enabled" : "disabled"}"]}"
    #disk_type       = "${var.disk_type}"
    #pricing_plan    = "${var.pricing_plan}"
    #database_flags  = ["${var.database_flags}"]
    tier = "${var.tier}"

    availability_type = "${var.availability_type}"
    disk_autoresize   = "${var.disk_autoresize}"
    disk_size         = "${var.disk_size}"

    #user_labels     = "${var.user_labels}"  

    # location_preference {
    #   zone = "${var.region}-${var.zone}"
    # }
    /*
       ip_configuration {
           ipv4_enabled = "false"
           private_network = "https://www.googleapis.com/compute/v1/projects/tf-deploy-1-6e1318de/global/networks/gen3-commons-us-central1"
       }
       */
    maintenance_window {
      day          = "${var.maintenance_window_day}"
      hour         = "${var.maintenance_window_hour}"
      update_track = "${var.maintenance_window_update_track}"
    }
  }

  lifecycle {
    ignore_changes = ["disk_size"]
  }
}

resource "google_sql_database" "default" {
  name     = "${var.db_name}"
  project  = "${var.project_id}"
  instance = "${google_sql_database_instance.default.name}"

  # charset    = "${var.db_charset}"
  # collation  = "${var.db_collation}"
  depends_on = ["google_sql_database_instance.default"]
}

/*
resource "google_sql_database" "additional_databases" {
  count      = "${length(var.additional_databases)}"
  project    = "${var.project_id}"
  name       = "${lookup(var.additional_databases[count.index], "name")}"
 # charset    = "${lookup(var.additional_databases[count.index], "charset", "")}"
 # collation  = "${lookup(var.additional_databases[count.index], "collation", "")}"
  instance   = "${google_sql_database_instance.default.name}"
  depends_on = ["google_sql_database_instance.default"]
}
*/

resource "random_id" "user-password" {
  keepers = {
    name = "${google_sql_database_instance.default.name}"
  }

  byte_length = 8
  depends_on  = ["google_sql_database_instance.default"]
}

resource "google_sql_user" "default" {
  name       = "${var.user_name}"
  project    = "${var.project_id}"
  instance   = "${google_sql_database_instance.default.name}"
  host       = "${var.user_host}"
  password   = "${var.user_password == "" ? random_id.user-password.hex : var.user_password}"
  depends_on = ["google_sql_database_instance.default"]
}
