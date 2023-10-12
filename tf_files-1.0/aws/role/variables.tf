variable "rolename" {
  description = "name of role"
}

variable "description" {
  description = "description of role"
  default     = "Role created with terraform"
}

variable "path" {
  description = "path attribute of role"
  default     = "/"
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
