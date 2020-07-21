
slurm_controllers_asg_name = "controllers_asg"

slurm_controller_subnet_id = ["", ""]
slurm_controller_sec_group = [""]

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
