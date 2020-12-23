# TL;DR

This module is intended to provide a configuration tool management customized for gen3.

## 1. QuickStart

### 1.1 Install Ansible

This module was created and tested using the following python/pip versions:

```
# pip -V
pip 19.2.3 from /usr/lib64/python3.7/site-packages/pip (python 3.7)
```

You can install ansible directly from pip

```
pip install ansible
```

### 1.2 Configure Ansible

Ansible by default will check for an inventory file in  `/etc/ansible/hosts`. You may want to run the folowing so you don't have to specify the inventory file every time you run ansible against a intem in the inventory.

EX:
```
export ANSIBLE_INVENTORY=~/cloud-automation/ansible/hosts.yaml
```

If everything is working correctly, the following command should output something similar to:

```
ansible --list-hosts all
  hosts (63):
    vm1_admin
    vm2_admin
    dev_commons
    qa_commons
    staging_commons
    prod_commons
    csocsquidnlbcentral1
    csocsquidnlbcentral2
    dummi1
```

More information in about configurations in https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installation-guide

## 2. Table of Contents

- [1. QuickStart](#1-quickstart)
- [2. Table of Contents](#2-table-of-contents)
- [3. Overiew](#3-overview)
- [4. Considerations](#4-considerations)


## 3. Overview

Once you have ansible installed and configured, you should be able to run playbooks and roles against items in the inventory.

EX:
```
# ansible -m ping cdistest_admin
cdistest_admin | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
```

```
ansible-playbook playbooks/removeKeys.yaml -e _hosts=cdistest_admin

PLAY [cdistest_admin] ***************************************************************************************************************

TASK [Gathering Facts] **************************************************************************************************************
ok: [cdistest_admin]

TASK [authorized_key] ***************************************************************************************************************
ok: [cdistest_admin] => (item=zflamig.keys)

PLAY RECAP **************************************************************************************************************************
cdistest_admin             : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

```
ansible cdistest_admin -m shell -a '/bin/bash ${HOME}/cloud-automation/files/scripts/module-update.sh management-logs'
cdistest_admin | CHANGED | rc=0 >>
ubuntu_management-logs has unapplied plan:
Plan: 0 to add, 2 to change, 0 to destroy.
Running terraform plan   --var-file ./config.tfvars out plan.terraform /home/ubuntu/cloud-automation/tf_files/aws/account_management-logs/
gen3_aws_run terraform plan --var-file ./config.tfvars -out plan.terraform /home/ubuntu/cloud-automation/tf_files/aws/account_management-logs/
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.

data.archive_file.lambda_function: Refreshing state...
aws_cloudwatch_log_group.management-logs_group: Refreshing state... (ID: cdistest_management-logs)
aws_cloudwatch_event_rule.event_rule: Refreshing state... (ID: cdistest-cloudtrail-StopLogging)
aws_s3_bucket.management-logs_bucket: Refreshing state... (ID: cdistest-management-logs)
aws_iam_role.the_role: Refreshing state... (ID: cdistest-security-alert-role)
data.aws_iam_policy_document.cloudtrail_access: Refreshing state...
aws_iam_role.cloudtrail_role: Refreshing state... (ID: management-logs_cloudtrail_role)
data.aws_region.current: Refreshing state...
data.aws_iam_policy_document.cloudwatchlogs_access: Refreshing state...
data.aws_iam_policy_document.sns_access: Refreshing state...
aws_iam_role_policy.lambda_policy_SNS: Refreshing state... (ID: cdistest-security-alert-role:cdistest-security-alert-policy-for-SNS)
aws_iam_role_policy.lambda_policy_CWL: Refreshing state... (ID: cdistest-security-alert-role:cdistest-security-alert-policy-for-CloudWatchLogs)
aws_iam_role_policy.lambda_policy_CT: Refreshing state... (ID: cdistest-security-alert-role:cdistest-security-alert-policy-for-CloudTrail)
aws_lambda_function.lambda_function: Refreshing state... (ID: cdistest-security-alert-lambda)
aws_cloudwatch_log_subscription_filter.csoc_subscription: Refreshing state... (ID: cwlsf-3322810899)
data.aws_iam_policy_document.cloudtrail_to_cloudwatch_policy_document: Refreshing state...
aws_iam_role_policy.cloudtrail_to_cloudwatch_policy: Refreshing state... (ID: management-logs_cloudtrail_role:cdistest_management-logs_policy)
aws_cloudwatch_event_target.sns: Refreshing state... (ID: cdistest-cloudtrail-StopLogging-terraform-20190911011508589700000003)
aws_cloudtrail.logs-trail: Refreshing state... (ID: cdistest_management_trail)
aws_s3_bucket_policy.b: Refreshing state... (ID: cdistest-management-logs)

------------------------------------------------------------------------

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  ~ update in-place

Terraform will perform the following actions:

  ~ module.logging.aws_cloudtrail.logs-trail
      event_selector.#:                           "0" => "1"
      event_selector.0.include_management_events: "" => "true"
      event_selector.0.read_write_type:           "" => "All"

  ~ module.logging.aws_cloudwatch_log_subscription_filter.csoc_subscription
      distribution:                               "ByLogStream" => ""


Plan: 0 to add, 2 to change, 0 to destroy.

------------------------------------------------------------------------

This plan was saved to: plan.terraform

To perform exactly these actions, run the following command to apply:
    terraform apply "plan.terraform"


WARNING: applying this plan will change your infrastructure.
    Do not apply a plan that 'destroys' resources unless you know what you are doing.

Use 'gen3 tfapply' to apply this plan, and backup the configuration variables
Running: terraform apply plan.terraform
gen3_aws_run terraform apply plan.terraform
module.logging.aws_cloudwatch_log_subscription_filter.csoc_subscription: Modifying... (ID: cwlsf-3322810899)
  distribution: "ByLogStream" => ""
module.logging.aws_cloudtrail.logs-trail: Modifying... (ID: cdistest_management_trail)
  event_selector.#:                           "0" => "1"
  event_selector.0.include_management_events: "" => "true"
  event_selector.0.read_write_type:           "" => "All"
module.logging.aws_cloudwatch_log_subscription_filter.csoc_subscription: Modifications complete after 0s (ID: cwlsf-3322810899)
module.logging.aws_cloudtrail.logs-trail: Modifications complete after 1s (ID: cdistest_management_trail)

Apply complete! Resources: 0 added, 2 changed, 0 destroyed.

Outputs:

cloudwatch_log_group = cdistest_management-logs
s3_bucket = cdistest-management-logs
Backing up files to s3
Backing up config.tfvars to s3://cdis-state-ac707767160287-gen3/cdistest_management-logs/config.tfvars
upload: ./config.tfvars to s3://cdis-state-ac707767160287-gen3/cdistest_management-logs/config.tfvars
Backing up backend.tfvars to s3://cdis-state-ac707767160287-gen3/cdistest_management-logs/backend.tfvars
upload: ./backend.tfvars to s3://cdis-state-ac707767160287-gen3/cdistest_management-logs/backend.tfvars
Backing up README.md to s3://cdis-state-ac707767160287-gen3/cdistest_management-logs/README.md
upload: ./README.md to s3://cdis-state-ac707767160287-gen3/cdistest_management-logs/README.md
```


## 4. Considerations

For runs like in the examples:
```
ansible cdistest_admin -m shell -a '/bin/bash ${HOME}/cloud-automation/files/scripts/module-update.sh management-logs'
```
you may want to be careful, it will run tfapply after taking a plan without asking for confirmation.
