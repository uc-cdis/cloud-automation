# Terraform Module - GCP VPC

Terraform module will create 3 VPCs, a subnet for each, vpc peering between them, and basic firewall rules for tcp:22,80,443.

## Documentation

Root module calls these modules.
* vpc - creates the VPC network and subnetworks
* fw-rule - creates the firewall rules
* vpc-peer - creates the VPC peering connections


### Usage

```terraform
module "commons_vpc" {
  source       = "../../vpc"
  
  project_id   = "prj-stage-wxyz-1e2471e8"
  network_name = "gen3-brain-commons"
  subnet_name = "kubecontrol"  

  subnet_octet1 = "172"  
  subnet_octet2 = "29"
  subnet_octet3 = "29"
  subnet_octet4 = "0"
  subnet_mask = "24"

  ip_cidr_range_k8_service = "10.170.80.0/20"
  ip_cidr_range_k8_pod = "10.56.0.0/14"
 
}
```
## Example
* Complete VPC Example

## Known Issues/Limitations
* None known at this point.


## Inputs
| Name                     | Description                                                                                                                                                                    | Type   | Default     | Required |
|--------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------|-------------|----------|
| network_name             | Name   of   the   VPC   resource.                                                                                                                                              | String | -           | yes      |
| project_id               | The   ID   of   the   project   in   which   the   resource   belongs.                                                                                                         | String | -           | yes      |
| region | Region the project is located in. |String| us-central1 | yes|
| subnet_octet1            | First   IP   octet                                                                                                                                                             | String | -           | yes      |
| subnet_octet2            | Second   IP   octet                                                                                                                                                            | String | -           | yes      |
| subnet_octet3            | Third   IP   octet                                                                                                                                                             | String | -           | yes      |
| subnet_octet4            | Fourth   IP   octet                                                                                                                                                            | String | -           | yes      |
| subnet_mask              | Subnet mask for the entire VPC.                                                                                                                                                | String | -           | yes      |
| subnet_flow_logs         | Whether   to   enable   flow   logging   for   this   subnetwork.                                                                                                              | String | true        | no       |
| subnet_private_access    | When   enabled ,  VMs   in   this   subnetwork   without   external   IP   addresses   can   access   Google   APIs   and   services   by   using   Private   Google   Access. | String | true        | no       |
| range_name_k8_service    | The   name   for   the   cluster   services.                                                                                                                                   | String | k8-services | yes      |
| ip_cidr_range_k8_service | The   IP   address   range   of   the   services   IPs   in   this   cluster.                                                                                                  | String | -           | yes      |
| range_name_k8_pod        | The   name   for   the   cluster   pods.                                                                                                                                       | String | k8-pods     | yes      |
| ip_cidr_range_k8_pod     | The   IP   address   range   of   the   pods   IPs   in   this   cluster.                                                                                                      | String | -           | yes      |
| subnet_name              | Name   of   the   subnet                                                                                                                                                       | String | -           | yes      |                                                                                                                                          

### Outputs
| Name                 | Description |
|----------------------|-------------|
| network_name         |             |
| network_self_link    |             |
| network_subnetwork   |             |
| network_id           |             |
| subnetwork_self_link |             |
| secondary_range_name |             |
