
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

variable "ami_account" {
  description = "AWS account ID AMI owner that will be used on the compute instaces that will power the slurm cluster"
  type        = string
  # Let's default to canonical's official AWS account 
  default     = "099720109477"
}

variable "slurm_cluster_image" {
  description = "Information about the AMI we want to use for our cluster"
  type        = map(list(string))
  default     = {
    "aws_accounts"         = ["099720109477"]
    "search_criteria"     = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
    "virtualization-type" = ["hvm"]
    "root-device-type"    = ["ebs"]
  }
}

variable "slurm_asgs" {
  description = "Information to use for the slurm crontrollers"
  type        = map(object({
    asg_name               = string
    instance_type          = string
    security_groups        = list(string)
    subnets_id             = list(string)
    public_ip              = bool
    recreate_on_lc_changes = bool
    desired_capasity       = number
    min_size               = number
    max_size               = number
    health_check_type      = string
    root_block             = map(string)
    tags                   = map(string)
  }))
  default     = {
    controllers = {
      asg_name               = "slurm-controllers"
      instance_type          = "t3.medium"
      security_groups        = []
      subnets_id             = []
      public_ip              = false
      recreate_on_lc_changes = false
      desired_capasity       = 1
      min_size               = 1
      max_size               = 1
      health_check_type      = "EC2"
      root_block             = {"volume_size" = "50", "volume_type" = "gp2", "delete_on_termination" = "true"}
      tags                   = {"Environment" = "Production", "Project" = "slurm"}
    },
    workers = {
      asg_name               = "slurm-workers"
      instance_type          = "t3.large"
      security_groups        = []
      subnets_id             = []
      public_ip              = false
      recreate_on_lc_changes = false
      desired_capasity       = 1
      min_size               = 1
      max_size               = 1
      health_check_type      = "EC2"
      root_block             = {"volume_size" = "50", "volume_type" = "gp2", "delete_on_termination" = "true"}
      tags                   = {"Environment" = "Production", "Project" = "slurm"}
    }
  }
}
    
