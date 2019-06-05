variable "display_name" {
  description = "The folder’s display name. A folder’s display name must be unique amongst its siblings."
}

variable "parent_folder" {
  description = "The name of the Organization in the form {organization_id} or organizations/{organization_id}"
}