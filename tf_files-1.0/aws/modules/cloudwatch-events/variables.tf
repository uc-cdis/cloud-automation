variable "cwe_rule_name" {
  description = "Name of the rule"
}

variable "cwe_rule_description" {
  description = "Brief description of the rule to use"
  default     = ""
}

variable "cwe_rule_pattern" {
  description = "Patter that the rule will use"
  default     = ""
}

variable "cwe_target_id" {
  description = "ID or name to use, if empty, something randon will be used"
  default     = ""
}

variable "cwe_target_arn" {
  description = "ARN of the target that this event will trigger"
}
