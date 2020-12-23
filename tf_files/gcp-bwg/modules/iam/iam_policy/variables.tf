variable "org_id_org_policies" {
  description = "Organization ID."
  default     = ""
}

variable "constraint" {
  description = "The name of of the Constraint Policy it is configuring."
  type        = "list"
  default     = []
}

variable "iam_policy_boolean_policy" {
  description = "Boolean value. Can either be true or false. Defaults to true."
  default     = true
}
