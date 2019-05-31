variable "display_name" {
  description = "The folder’s display name. A folder’s display name must be unique amongst its siblings."
}

variable "parent_folder" {
  description = "The name of the Organization in the form {organization_id} or organizations/{organization_id}"
}

variable "create_folder" {
  description = "Decide whether or not we need to create folders"
}

// Folder Level Roles
variable "kubernetes_cluster_viewer_folder_binding" {
  description = "Read-only access to Kubernetes Clusters. Role applied at folder level."
  type        = "list"
  default     = [""]
}

variable "kubernetes_engine_viewer_folder_binding" {
  description = "Provides read-only access to GKE resources. Role applied at folder level."
  type        = "list"
  default     = []
}

variable "stackdriver_monitoring_viewer_folder_binding" {
  description = "Provides read-only access to get and list information about all monitoring data and configurations at the folder level."
  type        = "list"
  default     = []
}

variable "log_viewer_folder_binding" {
  description = "Provides access to view logs. Role applied at folder level."
  type        = "list"
  default     = []
}

variable "compute_instance_viewer_folder_binding" {
  description = "Read-only access to get and list Compute Engine resources, without being able to read the data stored on them. Role applied at folder level."
  type        = "list"
  default     = []
}

variable "service_account_creator_folder_level" {
  description = "Create and manage service accounts at folder level."
  type        = "list"
  default     = []
}
