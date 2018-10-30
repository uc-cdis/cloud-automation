# TL;DR

Wrapper around `terraform plan`

## Use

```
  gen3 tfplan [--destroy]:
    Run 'terraform plan' in the current workspace, and generate plan.output.  
    A typical command line (under the hood) is:
       terraform plan --var-file ./config.tfvars -var-file ../../aws.tfvars -out plan.terraform ~/Code/PlanX/cloud-automation/tf_files/aws/commons 2>&1 | tee plan.log
    If '--destroy' is passed, then a destroy plan is generated.
    Execute a generated plan with 'gen3 tfapply'
```
