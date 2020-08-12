# TL;DR

Prepare the compute resoruces in AWS for a slurm cluster

## 1. QuickStart

```bash
gen3 workon <profile> <name>__slurm
```

Ex:
```bash
gen3 workon cdistest slurmtest__slurm
```

## 2. Table of content

- [1. QuickStart](#1-quickstart)
- [2. Table of Contents](#2-table-of-contents)
- [3. Overview](#3-overview)
- [4. Variables](#4-variables)
  - [4.1 Required Variables](#41-required-variables)
  - [4.2 Optional Variables](#42-optional-variables)
- [5. Outputs](#5-outputs)
- [6. Considerations](#6-considerations)



## 3. Overview

Once you workon the workspace, you may want to edit the config.tfvars accordingly.

There are mandatory variables, and there are a few other optionals that are set by default in the variables.tf file, but you could change them accordingly.

Ex.
```
vpc_name          = "devplanetv1"
organization_name = "planx"
cwlg_name         = "devplanetv1"


slurm_asgs = {
  "controllers" = {
      asg_name               = "slurm-controllers"
      instance_type          = "t3.large"
      security_groups        = ["sg-09719b7a0047ac0fc","sg-08609db84ed542c77"]
      subnets_id             = ["subnet-da215887"]
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
      security_groups        = ["sg-09719b7a0047ac0fc","sg-08609db84ed542c77"]
      subnets_id             = ["subnet-da215887"]
      public_ip              = false
      recreate_on_lc_changes = false
      desired_capasity       = 3
      min_size               = 1
      max_size               = 3
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
      name                                = "slurmdemo"
      username                            = "user"
      password                            = "YourPwdShouldBeLongAndSecure!"
      port                                = "3306"
      db_subnet_group_name                = "devplanetv1_private_group"
      maintenance_window                  = "Mon:00:00-Mon:03:00"
      backup_window                       = "03:00-06:00"
      vpc_security_group_ids              = ["sg-b39c1ec4"]
      subnet_ids                          = ["subnet-0cc5ef68", "subnet-da215887"]
      allocated_storage                   = 8
      deletion_protection                 = true
      iam_database_authentication_enabled = false
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
```

## 4. Variables

### 4.1 Required Variables

| Name | Description | Type | Default |
|------|-------------|:----:|:-------:|
| vpc_name | because these slurm cluster would be deployed within an existing cluster, we need to tell the module which one it is | string | |
| organization_name | for tagging purposes | string | |
| cwlg_name | cloudwatchloggroup where logs will be sent | |
| slurm_asgs | Information regarding the instances | |
| slurm_asgs.controllers.asg_name | name for the autoscaling group | string | slurm-controllers" |
| slurm_asgs.controllers.instance_type | instance type to use on the controllers | string | "t3.large" |
| slurm_asgs.controllers.security_greoups | sec groups you want applied on your controllers | list | [] |
| slurm_asgs.controllers.subnets_id | subnets where controllers will be on | list | [] |
| slurm_asgs.controllers.public_ip | should the controllers have public IPs | bool | false |
| slurm_asgs.controllers.recreate_on_lc_changes| recreate the autoscalingroup if the launch configuration changes | bool | false |
| slurm_asgs.controllers.desired_capasity | how many crontollers are wanted simultaneously | number | 1 |
| slurm_asgs.controllers.min_size | min size for the autoscaling group | number | 1 |
| slurm_asgs.controllers.max_size | max size for the autoscaling group | number | 1 |
| slurm_asgs.controllers.health_check_type | health check type for instances in the autoscaling group | string | "EC2" |
| slurm_asgs.controllers.root_block | root partition configuration | map | {"volume_size" = "50", "volume_type" = "gp2", "delete_on_termination" = "true"} |
| slurm_asgs.controllers.tags | tags to be carried on the intance belonging to the autoscaling group | map | {"Environment" = "Production", "Project" = "slurm"} |
| slurm_asgs.workers.asg_name | name for the autoscaling group | string | slurm-workers" |
| slurm_asgs.workers.instance_type | instance type to use on the workers | string | "t3.large" |
| slurm_asgs.workers.security_greoups | sec groups you want applied on your workers | list | [] |
| slurm_asgs.workers.subnets_id | subnets where workers will be on | list | [] |
| slurm_asgs.workers.public_ip | should the workers have public IPs | bool | false |
| slurm_asgs.workers.recreate_on_lc_changes| recreate the autoscalingroup if the launch configuration changes | bool | false |
| slurm_asgs.workers.desired_capasity | how many crontollers are wanted simultaneously | number | 1 |
| slurm_asgs.workers.min_size | min size for the autoscaling group | number | 1 |
| slurm_asgs.workers.max_size | max size for the autoscaling group | number | 1 |
| slurm_asgs.workers.health_check_type | health check type for instances in the autoscaling group | string | "EC2" |
| slurm_asgs.workers.root_block | root partition configuration | map | {"volume_size" = "50", "volume_type" = "gp2", "delete_on_termination" = "true"} |
| slurm_asgs.workers.tags | tags to be carried on the intance belonging to the autoscaling group | map | {"Environment" = "Production", "Project" = "slurm"} |
| main_os_user | for bootstraping purposes, which user is the main user | string | "ubuntu" |

### 4.2 Optional Variables

| Name | Description | Type |
|------|-------------|:----:|
| controller_info | extra information about the controllers | map |
| woker_info | extra information about the workers | map |
| source_bucket | should the cluster have access to buckets, which ones | list |


## 5. Outputs

| Name | Description | 
|------|-------------|
| output_bucket | bucket created with write access from the instances |
| rds_endpoint | endpoint for accessing the mySQL database |
| rds_password | password to use to connect to the database |
| rds_user | user to access the database |


## 6. Considerations

The cluster is not configured at the moment it deploys off this module, you may want to consider running an ansible playbook for the final bootstraping. [slurm role](https://github.com/uc-cdis/cloud-automation/blob/master/ansible/roles/slurm/README.md)

Please refer to the [Tungsten](https://github.com/NCI-GDC/tungsten/tree/develop/salt/srv/services/slurm) repo for additional informaion on slurm.


