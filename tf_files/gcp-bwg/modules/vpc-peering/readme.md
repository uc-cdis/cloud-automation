# Google VPC Peering Module
Manages a network peering within GCE. Both networks must create a peering with each other for the peering to be functional. Subnets IP ranges across peered VPC networks cannot overlap.

## Usage
This module will peer two differnet subnetworks together. Those subnetworks can live in the same organization id, or in different organizations. The peering is based off the globally unique project name in GCP

## Issues
There is a known race condition within GCP. GCP only allows peering-related activity at a time across peered networks. For example, if you set up peering with one network and immediately try to set up another, all the tasks from the first peering may not have completed. It may take up to a minute for all tasks to complete.


To help with this issue, a null resource in the module has been defined, but it has been seen where this sometimes may not give GCP enough time to provision the VPC peering. In addition, sequenced peering may be required.

## Example
```terraform
module "vpc-peering-csoc_private_to_ingress" {
  source = "../../../modules/vpc-peering"

  peer1_name = "ingress-private"
  peer2_name = "private-ingress"

  peer1_root_self_link = "${module.vpc-csoc-ingress.network_self_link}"
  peer1_add_self_link  = "${module.vpc-csoc-private.network_self_link}"

  peer2_root_self_link = "${module.vpc-csoc-private.network_self_link}"
  peer2_add_self_link  = "${module.vpc-csoc-ingress.network_self_link}"

  auto_create_routes = "true"
}
```


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| auto\_create\_routes | If set to true, the routes between the two networks will be created and managed automatically. Defaults to true. | string | `"true"` | no |
| peer1\_add\_self\_link | The ID of the CSOC project in which the resource belongs. | string | n/a | yes |
| peer1\_name | Name of the peer network in commons. | string | n/a | yes |
| peer1\_root\_self\_link | The ID of the project where this VPC will be created | string | n/a | yes |
| peer2\_add\_self\_link | The ID of the CSOC project in which the resource belongs. | string | n/a | yes |
| peer2\_name | Name of the peer network in csoc. | string | n/a | yes |
| peer2\_root\_self\_link | The ID of the project where this VPC will be created | string | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| network\_link | Resource link of the peer network for peer2. |
| peer1\_state\_details | Details about the current state of the peering for peer1. |
| peer1\_vpc\_state | State for the peering of peer1. |
| peer2\_state\_details | Details about the current state of the peering for peer2. |
| peer2\_vpc\_state | State for the peering of peer2. |
| peered\_network\_link | Resource link of the network to add a peering to for peer2. |