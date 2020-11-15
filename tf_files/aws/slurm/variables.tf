
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


variable "slurm_rds" {
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
    final_snapshot_identifier           = string
    db_subnet_group_name                = string
    allocated_storage                   = number
    vpc_security_group_ids              = list(string)
    subnet_ids                          = list(string)
    parameters                          = list(map(string))
    deletion_protection                 = bool
    iam_database_authentication_enabled = bool
    tags                                = map(string)
  }))
  default     = {
    slurmdb = {
      engine                              = "mysql"
      engine_version                      = "5.7.19"
      family                              = "mysql5.7"
      major_engine_version                = "5.7"
      instance_class                      = "db.t3.small"
      name                                = "demodb"
      username                            = "user"
      password                            = ""
      port                                = "3306"
      maintenance_window                  = "Mon:00:00-Mon:03:00"
      backup_window                       = "03:00-06:00"
      db_subnet_group_name                = ""
      allocated_storage                   = 8
      vpc_security_group_ids              = []
      subnet_ids                          = []
      deletion_protection                 = true
      iam_database_authentication_enabled = true
      parameters                          = [{
          name = "character_set_client"
          value = "utf8"
        },
        {
          name = "character_set_server"
          value = "utf8"
        }
      ]
      final_snapshot_identifier           = "slurm-database-final-ss"
      tags                                = {"Environment" = "Production", "Project" = "slurm"}
    }
  }
}


variable "main_os_user" {
  description = "Admin user for instances"
  default     = "ubuntu"
}

variable "branch" {
  description = "for testing purposes"
  default     = "master"
}

variable "authorized_keys" {
  description = "Keys file taken from cloud automation to set on the main use for troubleshooting bootstraping issues that might occur"
  default     = "files/authorized_keys/ops_team"
}

variable "cwlg_name" {
  description = "CloudWatch Log Group in which you want to send logs for this cluster"
}

variable "controller_info" {
  description = "Information about the controller instances needed for bootstraping"
  type        = map(string)
  default     = {
    bootstrap_script = "flavors/slurm/worker.sh"
    vm_role          = ""
    extra_vars       = ""
  }
}
  
variable "worker_info" {
  description = "Information about the workers instances needed for bootstraping"
  type        = map(string)
  default     = {
    bootstrap_script = "flavors/slurm/worker.sh"
    vm_role          = ""
    extra_vars       = ""
  }
}
 
variable "vpc_name" {
  description = "Given the fact that slurm clusters are to be deploying within exisings VPCs (commons environment), we want them assocuated somehow"
}

variable "organization_name" {
  description = "for tagging purposes"
  default     = "Basic Service"
}

variable "source_buckets" {
  description = "Where is the data that this cluster is going to access in s3"
  type        = list
}
