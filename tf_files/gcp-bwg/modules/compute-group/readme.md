# Managed Instance Groups Terraform Module

Managed Instance Group module to build instance groups, a load balancer, and a health-check with Terraform.

## Usage
```terraform
module "squid_instance_group" {
  source = "../../../modules/compute-group"

  name                    = "squid"
  project                 = "my-project"
  network_interface       = "vpc-network"
  subnetwork              = "vpc-subnetwork"
  tags                    = ["proxy", "web-access"]
  metadata_startup_script = "../../../modules/compute-group/scripts/squid-install.sh"
  hc_port                 = "3128"
}
```


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| access\_config | The access config block for the instances. Set to [] to remove external IP. | list | `<list>` | no |
| automatic\_restart | Specifies whether the instance should be automatically restarted if it is terminated by Compute Engine (not terminated by a user). This defaults to true. | string | `"true"` | no |
| base\_instance\_name | (Required) The name of the instances created in the group. | string | `"base-instance"` | no |
| can\_ip\_forward | Allow ip forwarding. | string | `"false"` | no |
| forwarding\_rule | Name of the forwarding rule. | string | `"forwarding-rule"` | no |
| forwarding\_rule\_port | Forwarding port range. Default set to 80. | string | `"80"` | no |
| hc\_port | The TCP port number for the HTTP health check request. The default value is 80. | string | `"80"` | no |
| health\_check\_name | Name of the health check. | string | `"health-check"` | no |
| instance\_group\_manager\_name | Name of the instance group. | string | `"instance-group"` | no |
| instance\_template\_name | Name of the template. | string | `"template"` | no |
| labels | A set of key/value label pairs to assign to instances created from this template. | map | `<map>` | no |
| machine\_type | (Required) The machine type to create for development. | string | `"f1-micro"` | no |
| metadata\_startup\_script | Location of metadata startup script | string | n/a | yes |
| name | The name of the instances. If you leave this blank, Terraform will auto-generate a unique name. | string | n/a | yes |
| network\_interface | Networks to attach to instances created from this template. | string | n/a | yes |
| network\_ip | Set the network IP of the instance in the template. Useful for instance groups of size 1. | string | `""` | no |
| on\_host\_maintenance | Defines the maintenance behavior for this instance. | string | `"MIGRATE"` | no |
| project | The ID of the project in which the resource belongs. | string | n/a | yes |
| region |  | string | `"us-central1"` | no |
| source\_image | The image from which to initialize this disk. | string | `"debian-cloud/debian-9"` | no |
| subnetwork | The name of the subnetwork to attach this interface to. The subnetwork must exist in the same region this instance will be created in. Either network or subnetwork must be provided. | string | n/a | yes |
| subnetwork\_project | The project the subnetwork belongs to. If not set, var.project is used instead. | string | `""` | no |
| tags | Tags to attach to the instance. | list | `<list>` | no |
| target\_pool\_name | Name of target-pool. | string | `"target-pool"` | no |
| target\_size | The target number of instances in the group. | string | `"1"` | no |
| zone | The zone which further specifies the region. | string | `"us-central1-c"` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance\_group | The full URL of the instance group created by the manager. |
| instance\_group\_self\_link | The URL of the created managed instance group resource. |
