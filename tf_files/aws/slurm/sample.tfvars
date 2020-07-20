
slurm_controllers_asg_name = "controllers_asg"
vpc_name                   = "INSERT VPC NAME HERE"

slurm_controller_subnet_id = ["", ""]
slurm_controller_sec_group = [""]

tags                     = {
  "Organization" = "PlanX"
  "Environment"  = "CSOC"
}
