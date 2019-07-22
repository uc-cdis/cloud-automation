# ----------------------------------------------------------
#   CHECK NETWORK DATA
# ----------------------------------------------------------

data "google_compute_network" "network" {
  project = "${var.project}"
  name    = "${var.network}"
}

data "google_compute_subnetwork" "subnetwork" {
  project = "${var.project}"
  name    = "${var.subnetwork}"
}

# -------------------------------------------------------------------------------
#   CREATE INTERNAL LOAD BALANCER
# -------------------------------------------------------------------------------

resource "google_compute_forwarding_rule" "default" {
  project               = "${var.project}"
  name                  = "${var.name}"
  region                = "${var.region}"
  network               = "${data.google_compute_network.network.self_link}"
  subnetwork            = "${data.google_compute_subnetwork.subnetwork.self_link}"
  load_balancing_scheme = "${var.load_balancing_scheme}"
  backend_service       = "${google_compute_region_backend_service.default.self_link}"
  ip_address            = "${var.ip_address}"
  ip_protocol           = "${var.ip_protocol}"
  ports                 = ["${var.ports}"]
}

resource "google_compute_region_backend_service" "default" {
  project          = "${var.project}"
  name             = "${var.name}"
  region           = "${var.region}"
  protocol         = "${var.ip_protocol}"
  timeout_sec      = 10
  session_affinity = "${var.session_affinity}"
  backend          = ["${var.backends}"]
  health_checks    = ["${element(compact(concat(google_compute_health_check.tcp.*.self_link,google_compute_health_check.http.*.self_link)), 0)}"]
}

resource "google_compute_health_check" "tcp" {
  count   = "${var.http_health_check ? 0 : 1}"
  project = "${var.project}"
  name    = "${var.name}-hc"

  tcp_health_check {
    port = "${var.health_port}"
  }
}

resource "google_compute_health_check" "http" {
  count   = "${var.http_health_check ? 1 : 0}"
  project = "${var.project}"
  name    = "${var.name}-hc"

  http_health_check {
    port = "${var.health_port}"
  }
}
