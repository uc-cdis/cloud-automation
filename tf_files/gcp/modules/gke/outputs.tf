# The following outputs allow authentication and connectivity to the GKE Cluster.
output "endpoint" {
  value = "${google_container_cluster.primary.endpoint}"
}

output "client_certificate" {
  value = "${google_container_cluster.primary.master_auth.0.client_certificate}"
}

output "client_key" {
  value = "${google_container_cluster.primary.master_auth.0.client_key}"
}

output "cluster_ca_certificate" {
  value = "${google_container_cluster.primary.master_auth.0.cluster_ca_certificate}"
}

output "admin_box_id" {
  value = "${google_compute_instance.admin_box.instance_id}"
}

output "admin_box_ip" {
  value = "${google_compute_instance.admin_box.network_interface.0.address}"
}

output "admin_box_nat_ip" {
  value = "${google_compute_instance.admin_box.network_interface.0.access_config.0.assigned_nat_ip}"
}
