/*
output "instance_template" {
  description = "Link to the instance_template for the group"
  value       = "${google_compute_instance_template.instance_template.*.self_link}"
}

output "instance_group" {
  description = "Link to the `instance_group` property of the instance group manager resource."
  value       = "${element(concat(google_compute_instance_group_manager.instance_group.*.instance_group, list("")), 0)}"
}

output "instances" {
  description = "List of instances in the instance group. Note that this can change dynamically depending on the current number of instances in the group and may be empty the first time read."
  value       = ["${google_compute_instance_group_manager.instance_group.*.self_link}"]
}

output "health_check" {
  description = "The healthcheck for the managed instance group"
  value       = ["${element(concat(google_compute_http_health_check.health_check.*.self_link, list("")), 0)}"]
}
*/

output "instance_group" {
  description = "The full URL of the instance group created by the manager."
  value       = "${google_compute_instance_group_manager.instance_group.instance_group}"
}

output "instance_group_self_link" {
  description = "The URL of the created managed instance group resource."
  value       = "${google_compute_instance_group_manager.instance_group.self_link}"
}
