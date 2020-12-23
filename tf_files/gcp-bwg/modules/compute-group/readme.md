# Managed Instance Groups Terraform Module

Managed Instance Group module to build instance groups, a load balancer, and a health-check with Terraform.

## Usage
```terraform
module "squid_instance_group" {
  source = "../../../modules/compute-group"

    project = "${var.project}"
    region = "${var.region}"
    zone = "${var.zone}"
    network_interface = "${var.network_interface}"
    subnetwork = "${var.subnetwork}"
    access_config = "${var.access_config}"
    automatic_restart = "${var.automatic_restart}"
    base_instance_name = "${var.base_instance_name}"
    can_ip_forward = "${var.can_ip_forward}"
    instance_group_manager_name = "${var.instance_group_manager_name}"
    instance_template_name = "${var.instance_template_name}"
    labels = "${var.labels}"
    machine_type = "${var.machine_type}"
    metadata_startup_script = "${var.metadata_startup_script}"
    name = "${var.name}"    
    network_ip = "${var.network_ip}"
    on_host_maintenance = "${var.on_host_maintenance}"    
    source_image = "${var.source_image}"    
    tags = "${var.tags}"
    target_pool_name = "${var.target_pool_name}"
    target_size = "${var.target_size}"
}
```


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| access\_config | The access config block for the instances. Set to [] to remove external IP. | list | n/a | yes |
| automatic\_restart | Specifies whether the instance should be automatically restarted if it is terminated by Compute Engine (not terminated by a user). This defaults to true. | string | n/a | yes |
| base\_instance\_name | (Required) The name of the instances created in the group. | string | n/a | yes |
| can\_ip\_forward | Allow ip forwarding. | string | n/a | yes |
| instance\_group\_manager\_name | Name of the instance group. | string | n/a | yes |
| instance\_template\_name | Name of the template. | string | n/a | yes |
| labels | A set of key/value label pairs to assign to instances created from this template. | map | n/a | yes |
| machine\_type | (Required) The machine type to create for development. | string | n/a | yes |
| metadata\_startup\_script | Location of metadata startup script | string | n/a | yes |
| name | The name of the instances. If you leave this blank, Terraform will auto-generate a unique name. | string | n/a | yes |
| network\_interface | Networks to attach to instances created from this template. | string | n/a | yes |
| network\_ip | Set the network IP of the instance in the template. Useful for instance groups of size 1. | string | n/a | yes |
| on\_host\_maintenance | Defines the maintenance behavior for this instance. | string | n/a | yes |
| project | The ID of the project in which the resource belongs. | string | n/a | yes |
| region | Region the projects lives in. | string | n/a | yes |
| source\_image | The image from which to initialize this disk. | string | n/a | yes |
| subnetwork | The name of the subnetwork to attach this interface to. The subnetwork must exist in the same region this instance will be created in. Either network or subnetwork must be provided. | string | n/a | yes |
| tags | Tags to attach to the instance. | list | n/a | yes |
| target\_pool\_name | Name of target-pool. | string | n/a | yes |
| target\_size | The target number of instances in the group. | string | n/a | yes |
| zone | The zone which further specifies the region. | string | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| instance\_group | The full URL of the instance group created by the manager. |
| instance\_group\_manager\_self\_link | The URL of the created group mananger. |
| instance\_group\_self\_link | The URL of the created managed instance group resource. |
