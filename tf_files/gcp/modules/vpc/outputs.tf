output "vpc_self_link" {
  value = "${google_compute_network.vpc.self_link}"
}

output "subnet_region1_name" {
  value = "${google_compute_subnetwork.region1.name}"
}
