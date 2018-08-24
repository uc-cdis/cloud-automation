//
// Managed cloud sql dbs for a commons VPC
//
data "google_compute_zones" "available" {}

resource "google_sql_database_instance" "fence-master" {
  name             = "fence-${var.vpc_name}"
  database_version = "POSTGRES_9_6"
  region           = "${var.gcp_region}"

  settings {
    # Second-generation instance tiers are based on the machine
    # type. See argument reference below.
    tier = "${var.db_tier}"

    ip_configuration {
      authorized_networks = [{
        value = "${var.authorized_cidr}"
      }]
    }

    availability_type = "${var.db_availability}"

    location_preference {
      zone = "${data.google_compute_zones.available.names[0]}"
    }
  }
}

resource "google_sql_user" "fence" {
  name     = "fence_user"
  instance = "${google_sql_database_instance.fence-master.name}"
  password = "${var.db_fence_password}"
}

resource "google_sql_database" "fence" {
  name      = "fence"
  instance  = "${google_sql_database_instance.fence-master.name}"
  charset   = "UTF8"
  collation = "en_US.UTF8"
}

//------------

resource "google_sql_database_instance" "sheepdog-master" {
  name             = "sheepdog-${var.vpc_name}"
  database_version = "POSTGRES_9_6"
  region           = "${var.gcp_region}"

  settings {
    # Second-generation instance tiers are based on the machine
    # type. See argument reference below.
    tier = "${var.db_tier}"

    availability_type = "${var.db_availability}"

    ip_configuration {
      authorized_networks = [{
        value = "${var.authorized_cidr}"
      }]
    }

    location_preference {
      zone = "${data.google_compute_zones.available.names[0]}"
    }
  }
}

resource "google_sql_user" "sheepdog" {
  name     = "sheepdog"
  instance = "${google_sql_database_instance.sheepdog-master.name}"
  password = "${var.db_sheepdog_password}"
}

resource "google_sql_user" "peregrine" {
  name     = "peregrine"
  instance = "${google_sql_database_instance.sheepdog-master.name}"
  password = "${var.db_sheepdog_password}"
}

resource "google_sql_database" "sheepdog" {
  name      = "gdcapi"
  instance  = "${google_sql_database_instance.sheepdog-master.name}"
  charset   = "UTF8"
  collation = "en_US.UTF8"
}

//----------------

resource "google_sql_database_instance" "indexd-master" {
  name             = "indexd-${var.vpc_name}"
  database_version = "POSTGRES_9_6"
  region           = "${var.gcp_region}"

  settings {
    # Second-generation instance tiers are based on the machine
    # type. See argument reference below.
    tier = "${var.db_tier}"

    availability_type = "${var.db_availability}"

    ip_configuration {
      authorized_networks = [{
        value = "${var.authorized_cidr}"
      }]
    }

    location_preference {
      zone = "${data.google_compute_zones.available.names[0]}"
    }
  }
}

resource "google_sql_user" "indexd" {
  name     = "indexd_user"
  instance = "${google_sql_database_instance.indexd-master.name}"
  password = "${var.db_indexd_password}"
}

resource "google_sql_database" "indexd" {
  name      = "indexd"
  instance  = "${google_sql_database_instance.indexd-master.name}"
  charset   = "UTF8"
  collation = "en_US.UTF8"
}
