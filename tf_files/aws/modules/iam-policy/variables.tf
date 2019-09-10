
variable "policy_name" {
  description = "Name for the policy"
}

variable "policy_path" {
  description = "Path in which to create the policy. "
}

variable "policy_description" {
  description = "Description for the policy"
  default     = ""
}

variable "policy_json" {
  description = "Basically the actual policy in JSON"
}


