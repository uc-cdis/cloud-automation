Role Name
=========

bootsrtrap ec2 instances to planX standards.


Requirements
------------

boto2

Role Variables
--------------

cloudwatch_log_group: cloudwatch group to send logs to

Dependencies
------------

N/A

Example Playbook
----------------


```yaml
- hosts: servers
  tasks:
    - import_role: aws_common
```


License
-------

BSD

Author Information
------------------

Fauzi Gomez
University of Chicago
CTDS
