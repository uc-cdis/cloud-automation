variable "job_id" {}

variable "prefix" {}

variable "batch_job_definition_name" {
  description = "batch job defintion name"
}

variable "container_properties" {
  description = "container properties" 
}

variable "iam_instance_role" {}

variable "iam_instance_profile_role" {}

variable "aws_batch_service_role" {}

variable "aws_batch_compute_environment_sg" {}

variable "compute_environment_name" {}

variable "instance_type" {
  description = "ec2 instance type to handle the job"
  type        =  list(string)
  default     =  ["c4.large"]
}

variable "priority" {
  default = 10
  description = "job priority"
}


variable "max_vcpus" {
  default     = 256
  description = "The maximum number of EC2 vCPUs that an environment can reach"
}

variable "min_vcpus" {
  default     = 0
  description = "The maximum number of EC2 vCPUs that an environment should maintain"
}

variable "compute_env_type" {
  default     = "EC2"
  description = "The type of compute environment. Valid items are EC2 or SPOT"
}

variable "compute_type" {
  default     = "MANAGED"
  description = "MANAGED or UNMANAGED"
}

variable "ec2_key_pair" {
  default     = "emalinowski"
  description = "The EC2 key pair that is used for instances launched in the compute environment."
}

variable "batch_job_queue_name" {
  description = "batch job queue name"
}

variable "sqs_queue_name" {
  description = "sqs queue name"
}

variable "output_bucket_name" {
  description = "output bucket"
}
