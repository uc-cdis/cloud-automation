# The following outputs allow authentication and connectivity to the GKE Cluster.
output "k8s_endpoint" {
  value = "${module.k8s.endpoint}"
}

output "k8s_client_certificate" {
  value = "${module.k8s.client_certificate}"
}

output "k8s_client_key" {
  value = "${module.k8s.client_key}"
}

output "k8s_cluster_ca_certificate" {
  value = "${module.k8s.cluster_ca_certificate}"
}

output "admin_box_id" {
  value = "${module.k8s.admin_box_id}"
}

output "admin_box_ip" {
  value = "${module.k8s.admin_box_ip}"
}

output "admin_box_nat_ip" {
  value = "${module.k8s.admin_box_nat_ip}"
}
