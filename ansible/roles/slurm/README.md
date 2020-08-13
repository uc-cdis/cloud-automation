Role Name
=========

Install and configure all about slurm cluster. The module should be ran against all memebers of the cluster in which a hosts file looks like 

```yaml
---
all:
  children:
    controller:
      hosts:
        ansible_host: ip-172-24-66-242.ec2.internal
      vars:
        ansible_user: ubuntu
        ansible_python_interpreter: /usr/bin/python3
    workers:
      hosts:
        ip-172-24-66-40.ec2.internal
        ip-172-24-66-150.ec2.internal
        ip-172-24-66-136.ec2.internal
      vars:
        ansible_user: ubuntu
        ansible_python_interpreter: /usr/bin/python3
```


Requirements
------------

boto2


Role Variables
--------------

cluster: name for the cluster.
workers_cpu: number of CPUs that workers have.
workers_gres: size of the volume attaches to the workers.
mysql_db_endpoint: endpoint for the mysql database.
mysql_db_name: name for the database to be used.
mysql_db_user: user with access to the database.
mysql_db_pass: password to connect to the database
region: region where the compute instaces are
slurm_source_url: url where the slurm source code is
slurm_version: slurm version to use
nodejs_version: nodejs version to isntall on the wokers 


Dependencies
------------

role: aws_common
      variable: cloudwatch_log_group where the instances are sending logs to.

role: docker


Example Playbook
----------------

```yaml
---
- hosts: controller
  name: gather controller facts
  tasks: [ ]
- hosts: all
  tasks:
    - debug:
        msg: "before we run our role"
    - import_role:
        name: aws_common
    - import_role:
        name: docker
    - import_role:
        name: slurm
      vars:
        region: 'us-east-1'
        slurm_source_url: 'https://github.com/SchedMD/slurm/archive/'
        slurm_version: 'slurm-20-02-3-1'
        nodejs_version: '10.x'
```

You can run the playbook either adding the required varibales in the playbook or though the command line

```bash
ansible-playbook -i hosts-slurm2.yaml playbooks/slurm_cluster.yaml -e "cloudwatch_log_group=devplanetv1" -e "cluster=slurmstuff2" -e "workers_cpu=2" -e "workers_gres=40" -e "mysql_db_endpoint=slurmdemo2.cwvizkxhzjt8.us-east-1.rds.amazonaws.com" -e "mysql_db_name=something2" -e "mysql_db_pass=YourPwdShouldBeLongAndSecure" -e "mysql_db_user=user"
```

License
-------

BSD

Author Information
------------------

Fauzi Gomez
University of Chicago
CTDS
