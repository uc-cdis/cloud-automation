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

variable "priority" {
  default = 10
  description = "job priority"
}


variable "max_vcpus" {
  default = 256
  description = "The maximum number of EC2 vCPUs that an environment can reach"
}

variable "min_vcpus" {
  default = 0
  description = "The maximum number of EC2 vCPUs that an environment should maintain"
}

variable "compute_env_type" {
  default = "EC2"
  description = "The type of compute environment. Valid items are EC2 or SPOT"
}

variable "ec2_key_pair" {
  default = ""
  description = "The EC2 key pair that is used for instances launched in the compute environment."
}

variable "batch_job_queue_name" {
  description = "batch job queue name"
}
