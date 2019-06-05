output "private_ip" {
  description = "list private ip on compute instance"
  value       = ["${module.compute_instance.private_ip}"]
}
