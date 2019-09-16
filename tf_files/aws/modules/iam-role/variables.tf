

variable "role_name" {
  description = "Name for the role to be created"
}

variable "role_assume_role_policy" {
  description = "Assume role policy in JSON format"
}

variable "role_tags" {
  description = "Tags for the role"
  type        = "map"
  default     = {}
}

variable "role_force_detach_policies" {
  description = "Specifies to force detaching any policies the role has before destroying it. Defaults to false."
  default     = "false"
}

variable "role_description" {
  description = "Description for the role"
  default     = ""
}

