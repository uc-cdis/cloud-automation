variable "role_name" {
  description = "role name"
}

variable "role_description" {
  description = "role description"
}

variable "batch_job_definition_name" {
  description = "batch job defintion name"
}

variable "batch_job_image" {
  description = "batch job image"
}

variable "batch_job_cmd" {
  type = "list"
  default = ["ls", "-la"]
}

variable "compute_environment_name" {
}

variable "instance_type" {
  description = "ec2 instance type to handle the job"
  type  =  "list"
  default  =  ["c4.large"]
}

variable "subnets" {
  type = "list"
  description = "list of subnets job instances will live"
}

variable "batch_job_queue_name" {
  description = "batch job queue name"
}
