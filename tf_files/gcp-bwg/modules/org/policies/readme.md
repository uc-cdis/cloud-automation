# Terraform Module - IAM Policy in Google
This Terraform module configures organization policies which are disabled by default. Pass in a list value of services that are desired to be enabled from the organization level down through all other resources.

## Requirements
### Terraform plugins
* Terraform 0.11.x
* terraform-provider-google 1.20.x
* terraform-provider-google-beta 1.20.x

### Permissions
A service account was used during provisioning and is the recommneded way to deploy IAM policies in GCP. The service account will require the following permissions:
* Service account requires Organization Policy Administrator role to edit organization level policies

## Documentation
Root module calls this one sub-module.
* iam_policy - pass in a list of services that are required to be enabled at the organization level.


### Usage
A full example is in the examples folder, but basic usage is as to pass in a list of policies that are desired to be enabled for the environment.
```terraform
module "set_iam_policies" {
  source = "../../iam_policy"

  org_id_org_policies = "123456789123"
  constraint          = ["constraints/compute.disableNestedVirtualization",
                        "constraints/compute.disableSerialPortAccess",
                        "constraints/compute.skipDefaultNetworkCreation"]
}
```



## Inputs
| Name                | Description                                                                | Type   | Default | Required |
|---------------------|----------------------------------------------------------------------------|--------|---------|----------|
| org_id_org_policies | The organization ID.                                                       | String | ""      | yes      |
| constraint          | List of policies that are desired to be enabled at the organization level. | List   | []      | no       |
|                     |                                                                            |        |         |          |

## Outputs
None

