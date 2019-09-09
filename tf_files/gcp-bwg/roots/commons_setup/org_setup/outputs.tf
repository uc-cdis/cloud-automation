/*******************************************
*    Create Folders
*******************************************/

output "folder" {
  value       = "${module.folders.folder_name}"
  description = "The name of the folder being created."
}

output "folder_id" {
  value = "${module.folders.folder_id}"
}

output "parent_folder" {
  value = "${module.folders.parent_folder}"
}

output "folder_create_time" {
  value       = "${module.folders.folder_create_time}"
  description = "The time the folder was created."
}

/*******************************************
*    Create Projects
*******************************************/
output "project_name" {
  value = "${module.project.project_name}"
}

output "project_id" {
  value = "${module.project.project_id}"
}

output "project_number" {
  value = "${module.project.project_number}"
}

output "project_apis" {
  value = "${module.project.project_apis}"
}
