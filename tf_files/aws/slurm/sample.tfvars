#TODO this one will require more investigation and merging
vpc_name          = "PUT SOMETHING HERE, usually ${vpc_name}"
organization_name = "For taggin purposes"
cwlg_name         = "which CloudWatch Log group you want logs to be sent over"


slurm_asgs = {
  "controllers" = {
      asg_name               = "slurm-controllers"
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
  },
  "workers"     = {
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


slurm_rds = {
  "slurmdb" = {
      engine                              = "mysql"
      engine_version                      = "5.7.19"
      family                              = "mysql5.7"
      major_engine_version                = "5.7"
      instance_class                      = "db.t3.small"
      name                                = "demodb"
      username                            = "user"
      password                            = ""
      port                                = "3306"
      db_subnet_group_name                = ""
      maintenance_window                  = "Mon:00:00-Mon:03:00"
      backup_window                       = "03:00-06:00"
      vpc_security_group_ids              = []
      subnet_ids                          = []
      allocated_storage                   = 8
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



main_os_user    = "ubuntu"

controller_info = {
  bootstrap_script = "flavors/slurm/controller.sh"
  vm_role          = ""
  extra_vars       = ""
}

worker_info     = {
  bootstrap_script = "flavors/slurm/worker.sh"
  vm_role          = ""
  extra_vars       = ""
}

source_buckets = ["sorce1","source3"]
