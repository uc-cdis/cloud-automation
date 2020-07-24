
variable "slurm_cluster_region" {
  description = "Region in where to deploy the resources"
  type        = string
  default     = "us-east-1"
}


variable "slurm_cluster_image" {
  description = "Information about the AMI we want to use for our cluster"
  type        = map(list(string))
  default     = {
    "aws_accounts"        = ["099720109477"]
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


variable "rds_instance" {
  description = "Information about the database for the slurm cluster"
  type        = map(object({
    engine                              = string
    engine_version                      = string
    family                              = string
    major_engine_version                = string
    instance_class                      = string
    name                                = string
    username                            = string
    password                            = string
    port                                = string
    maintenance_window                  = string
    backup_window                       = string
    allocated_storage                   = number
    final_snapshot_identifier           = string
    vpc_security_group_ids              = list(string)
    subnet_ids                          = list(string)
    deletion_protection                 = bool
    parameters                          = list(map(string))
    iam_database_authentication_enabled = bool
  }))
  default     = {
    engine                 = "mysql"
    engine_version         = "5.7.19"
    family                 = "mysql5.7"
    major_engine_version   = "5.7"
    instance_class         = "db.t3.small"
    allocated_storage      = 8
    name                   = "demodb"
    username               = "user"
    password               = "YourPwdShouldBeLongAndSecure!"
    port                   = "3306"
    vpc_security_group_ids = ""
    maintenance_window     = "Mon:00:00-Mon:03:00"
    backup_window          = "03:00-06:00"
    subnet_ids             = ""
    deletion_protection    = true
    
    final_snapshot_identifier = "slurm-database-final-ss"
    iam_database_authentication_enabled = true


