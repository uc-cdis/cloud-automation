variable "org_id_org_externalIP" {
  description = "Organization ID."
  default     = "575228741867"
}

variable "org_iam_externalipaccess" {
  description = "List of VMs that are allowed to have external IP addresses."
  type        = "list"
  default     = []
}
