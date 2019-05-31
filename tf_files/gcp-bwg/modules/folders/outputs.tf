output "folder_name" {
  value       = "${join("",google_folder.department.*.name)}"
  description = "The name of the folder being created."
}

output "folder_id" {
  value       = "${join("",google_folder.department.*.id)}"
  description = "The name of the folder being created."
}

output "parent_folder" {
  value       = "${join("",google_folder.department.*.parent)}"
  description = "The name of the folder being created."
}

output "folder_create_time" {
  value       = "${join("",google_folder.department.*.create_time)}"
  description = "The time the folder was created."
}
