# Terraform Module - IAM Policy External IP Access in Google
This Terraform module configures the organization policy labeled "Define allowed external IPs for VM instances", which is disabled by default. Enabled this policy to control what virtual machines will be allowed to have an external IP address.

This policy will enable the policy so you'll have to list the virtual machines that are allowed to have external IP addresses.
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| org\_iam\_externalipaccess | List of VMs that are allowed to have external IP addresses. | list | `<list>` | no |
| org\_id\_org\_externalIP | Organization ID. | string | `""` | no |