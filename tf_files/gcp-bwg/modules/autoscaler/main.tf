resource "google_compute_autoscaler" "default" {
  project = "${var.project}"
  name    = "${var.name}"
  zone    = "${var.zone}"
  target  = "${var.target_instance_group}"

  autoscaling_policy {
    max_replicas    = "${var.max_replicas}"
    min_replicas    = "${var.min_replicas}"
    cooldown_period = "${var.cooldown_period}"

    cpu_utilization {
      target = "${var.cpu_utilization_target}"
    }
  }
}
