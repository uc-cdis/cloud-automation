# TL;DR

Run terraform in the current [workspace](./workon.md)

# Use

```
  gen3 tfapply:
    Run 'terraform apply' in the current workspace, and backup config.tfvars, backend.tfvars, and README.md.  
    A typical command line is:
       terraform apply plan.terraform
```
