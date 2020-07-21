
variable "slurm_cluster_region" {
  description = "Region in where to deploy the resources"
  type        = string
  default     = "us-east-1"
}

variable "slurm_controllers_asg_name" {
  description = "Name for the Autoscaling Group that would handle controller instances"
  type        = string
  default     = "slurm-controllers"
}

variable "slurm_controller_instance_type" {
  description = "Instance type for the crontrollers"
  type        = string
  default     = "t2.micro"
}

variable "slurm_controller_sec_group" {
  description = "Security group to associate the controllers with"
  type        = list(string)
}

variable "slurm_controller_associate_public_ip" {
  description = "Associate the controller to a public IP"
  type        = bool
  default     = false
}

variable "slurm_controller_recreate_when_lc_changes" {
  description = "Should the autoscaling group recreate after changes in the launch configuration"
  type        = bool
  default     = false
}

variable "slurm_controller_subnet_id" {
  description = "Subnet ids to assoaciate the controllers"
  type        = list(string)
}

