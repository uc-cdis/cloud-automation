variable "vpc_name" {}

# Iam Role Vars
variable "rolename" {
  description = "name of role"
  default     = "hatchery-service-account"
}

variable "roledescription" {
  description = "description of role"
  default     = "Role created with terraform"
}

variable "ar_policy" {
  description = "assume-role policy to attach to the role"
  default     = <<EOR
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
EOR
}

variable "rolepath" {
  description = "path attribute of role"
  default     = "/"
}




# Iam Policy Vars
variable "policyname" {
  description = "name of policy"
  default     = "hatchery-policy"
}

variable "policydescription" {
  description = "description of policy"
  default     = "Allow hathcery to assume csoc_adminvm role in other accounts, for multi-account workspaces"
}

variable "policypath" {
  description = "path attribute of policy"
  default     = "/"
}