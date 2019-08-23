# Terraform Module - Deploy GCP Managed Instance and Internal Load Balancer

Terraform module which deploys compute instances in Google Cloud Platform.

Module will also create managed instances groups and create an internal load balancer to be used infront of the managed instance groups.

This tells how to and why to create the LB in front of the squid proxy.

![alt text](https://storage.googleapis.com/gcp-community/tutorials/modular-load-balancing-with-terraform/terraform-google-lb-internal-diagram.png)

## Documentation

Root module calls these modules.
* compute - Creates a GCP Compute instance.

### Usage

```terraform

```
## Example
* Complete create Instance Example

## Known Issues/Limitations
* None known at this time.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| activity\_filter | The filter to apply when exporting logs. | string | `"logName:activity"` | no |
| activity\_sink\_name | The name of the logging sink. | string | n/a | yes |
| auto\_delete | Whether the disk will be auto-deleted when the instance is deleted. Defaults to true | string | `"true"` | no |
| automatic\_restart | Specifies if the instance should be restarted if it was terminated by Compute Engine (not a user). Defaults to true. | string | `"true"` | no |
| bastion\_compute\_tags | A list of tags to attach to the instance. | list | n/a | yes |
| bucket\_activity\_logs | Bucket name for admin activity logs. | string | `"admin_activity_logs"` | no |
| bucket\_class | Bucket storage class. | string | `"REGIONAL"` | no |
| bucket\_data\_access\_logs | Bucket name for data access logs. | string | `"data_access_activity_logs"` | no |
| bucket\_destroy | Destroy the bucket and all the objects. | string | `"true"` | no |
| compute\_labels | a map of key value pairs describing the system or its environment | map | n/a | yes |
| compute\_tags | A list of tags to attach to the instance. | list | n/a | yes |
| count\_compute | The total number of instances to create. | string | `"1"` | no |
| count\_start |  | string | `"1"` | no |
| credential\_file | The service account key json file being used to create this project. | string | `"../credentials.json"` | no |
| data\_access\_filter | The filter to apply when exporting logs. | string | `"logName:data_access"` | no |
| data\_access\_sink\_name | The name of the logging sink. | string | n/a | yes |
| env | Development Environment suffix for project name. | string | n/a | yes |
| environment | (Required)Select envrironment type of prod or dev to change instance types. Prod = n1-standard-1, dev = g1-small | string | `"dev"` | no |
| image\_name | (Required) The name of a specific image or a family. | string | n/a | yes |
| ingress\_subnetwork\_name | (Required)Name of the subnetwork in the ingress VPC. | string | n/a | yes |
| instance\_name | (Required) A unique name for the resource, required by GCE. Changing this forces a new resource to be created. | string | n/a | yes |
| machine\_type\_dev | (Required) The machine type to create for development. | string | `"g1-small"` | no |
| machine\_type\_prod | (Required) The machine type to create for production. | string | `"n1-standard-1"` | no |
| on\_host\_maintenance | (Optional) Describes maintenance behavior for the instance. Can be MIGRATE or TERMINATE | string | `"MIGRATE"` | no |
| openvpn\_compute\_tags | A list of tags to attach to the instance. | list | `<list>` | no |
| openvpn\_install\_script | The file path of the shell script to install openVPN | string | `"../../../openVPN-Install.sh"` | no |
| openvpn\_instance\_name | The name of the OpenVPN instance. | string | `"openvpn-instance"` | no |
| org\_id | The numeric ID of the organization to be exported to the sink. | string | n/a | yes |
| prefix\_org\_setup | The prefix being used by the org_setup section of the terraform project to create the directory in cloud storage for remote state | string | n/a | yes |
| prefix\_project\_setup | The prefix being used by the project_setup section of the terraform project to create the directory in cloud storage for remote state | string | n/a | yes |
| project\_name | The ID of the project in which the resource belongs. | string | n/a | yes |
| region | The region the project resides. | string | `"us-central1"` | no |
| scopes | Service Account block | list | `<list>` | no |
| size | The size of the image in gigabytes. | string | `"15"` | no |
| squid\_install\_script | The file path of the shell script to install squid | string | `"../../../squidInstall.sh"` | no |
| squid\_instance\_name | The name of the Squid instance. | string | `"squid_instance"` | no |
| ssh\_key | The ssh key to use | string | n/a | yes |
| ssh\_key\_pub | The public key to insert for the ssh key we want to use | string | n/a | yes |
| ssh\_user | The user we want to insert an ssh-key for | string | n/a | yes |
| state\_bucket\_name | The cloud storage bucket being used to store the resulting remote state files | string | `"my-tf-state"` | no |
| subnetwork\_name | (Required)Name of the subnetwork in the VPC. | string | n/a | yes |
| terraform\_workspace | The filename being used for the remote state storage on GCP Cloud Storage Buckets | string | `"my-workspace"` | no |
| type | The GCE disk type. | string | `"pd-standard"` | no |

## Outputs

| Name | Description |
|------|-------------|
| openvpn\_instance\_group | OpenVPN instance group name. |
| openvpn\_instance\_group\_self\_link | OpenVPN instance group self link. |
| org\_activity\_writer\_identity | The identity associated with this sink. |
| org\_data\_access\_writer\_identity | The identity associated with this sink. |
| private\_ip | list private ip on compute instance |
| public\_ssh\_key | The public key we inserted |
| squid\_ilb\_ip\_address | The internal IP assigned to the regional fowarding rule. |
| squid\_instance\_group | Squid instance group name. |
| squid\_instance\_group\_self\_link | Squid instance group self link |
| storage\_bucket\_activity\_name | Storage bucket name for admin activity. |
| storage\_bucket\_data\_access\_name | Storage bucket name for data access. |