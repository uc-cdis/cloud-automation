output "instance_group_manager_self_link" {
  description = "The URL of the created group mananger."

  #value = "${join(", ", google_compute_instance_group_manager.instance_group.self_link)}"
  value = "${google_compute_instance_group_manager.instance_group.self_link}"
}

output "instance_group" {
  description = "The full URL of the instance group created by the manager."
  value       = "${google_compute_instance_group_manager.instance_group.instance_group}"
}

output "instance_group_self_link" {
  description = "The URL of the created managed instance group resource."
  value       = "${google_compute_instance_group_manager.instance_group.self_link}"
}
