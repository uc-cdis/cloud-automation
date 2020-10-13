# TL;DR

Deploy a slurm cluster in a VPC

This module and anything else related to slurm was taken from https://github.com/NCI-GDC/tungsten/tree/develop/salt/srv/services/slurm

So please refer to that repo for additinal information

## Deploy resources in with Terraform

Firstly, you want to load the module

```bash
gen3 workon <profile> <slurmName>__slurm
```

Ex:
```bash
gen3 workon cdistest slurmtest__slurm
```

Then access the config file

```bash
gen3 cd
vim config.tfvars
```

The configuration file should look something like:

```bash
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
      engine_version                      = "8.0.17"
      family                              = "mysql8.0"
      major_engine_version                = "8.0"
      instance_class                      = "db.t3.small"
      name                                = "slurmdemo"
      username                            = "gdc_slurm"
      password                            = ""
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

# buckets we want slurm to have access read access
source_buckets = ["sorce1","source3"]
```


Then create a plan and apply it. 

```bash
Outputs:

output_bucket = devplanetv1-slurm-data-bucket
rds_endpoint = slurmdemo.cwvizkxhzjt8.us-east-1.rds.amazonaws.com:3306
rds_password = 
rds_user = user
```

You may need to use the output later


## Installing and configuring slurm

All software installations and configurations can be done through ansible.

### hosts file

Create host file with the information of the instances that will be part of the cluster:

```bash
$ cat hosts-slurm.yaml
---
all:
  children:
    controller:
      hosts:
        slurm_controller:
          ansible_host: ip-172-24-66-180.ec2.internal
      vars:
        ansible_user: ubuntu
        ansible_python_interpreter: /usr/bin/python3
    workers:
      hosts:
        worker1:
          ansible_host: ip-172-24-66-11.ec2.internal
        worker2:
          ansible_host: ip-172.24.66.99.ec2.internal
      vars:
        ansible_user: ubuntu
        ansible_python_interpreter: /usr/bin/python3
```

Should you need to list all the workers in an account (supposing there is only on single slurm cluster per account), you can run the following one liner:

```bash
aws ec2 describe-instances --instance-ids $(aws autoscaling describe-auto-scaling-groups |jq -r '.AutoScalingGroups[]| select(.AutoScalingGroupName |contains("slurm-workers")) |.Instances[].InstanceId') --query 'Reservations[].Instances[].PrivateDnsName'
```

### the playbook
Then execute the playbook like this

[slurm_cluster.yanl](https://github.com/uc-cdis/cloud-automation/blob/master/ansible/playbooks/slurm_cluster.yaml)


```bash
devplanetv1@cdistest_dev_admin:~/cloud-automation/ansible$ ansible-playbook -i hosts-slurm.yaml playbooks/slurm_cluster.yaml \
  -e "cloudwatch_log_group=${vpc_name}" -e "cluster=slurmstuff" -e "workers_cpu=2" -e "workers_gres=40" \
  -e "mysql_db_endpoint=slurmdemo.cwvizkxhzjt8.us-east-1.rds.amazonaws.com" -e "mysql_db_name=bio_slurm" \
  -e "mysql_db_pass="
```

`cloudwatch_log_group` is where to send instances logs.

`cluster` how you want you cluster named.

`workers_cpu` the vCPU of instances selected for the workers (it depends on the instance type.

`workers_gres` this has to be slightly less than the volume size selected for the workers.

`mysql_db_endpoint` outputed by terraform at the moment of deployment.

`mysql_db_name` the name of the database slurm will use.

`mysql_db_pass` the password to access the database 


