# Google Compute Autoscaler


This terraform module provisions a Google Cloud autoscaler.  This module uses cpu utilization as the criteria for scaling.
This module needs to be used with the managed instance group module.

## Usage Example

```hcl
module "my_bucket" {
  source             = "/modules/autoscaler"

  # Required Parameters:
  project = "${var.project}"
  name   = "${var.name}"
  zone   = "${var.zone}"
  target = "${var.target_instance_group}"
  max_replicas    = "${var.max_replicas}"
  min_replicas    = "${var.min_replicas}"
  cpu_utilization_target = "${var.cpu_utilization_target}"

  # Optional Parameters:
  cooldown_period = "${var.cooldown_period}"
  
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| cooldown\_period | The number of seconds that the autoscaler should wait before it starts collecting information from a new instance. | string | n/a | yes |
| cpu\_utilization\_target | Defines the CPU utilization policy that allows the autoscaler to scale based on the average CPU utilization of a managed instance group. Must be a float value in the range (0, 1]. Example 0.6 is 60% | string | n/a | yes |
| max\_replicas | The maximum number of replicas that the autoscaler can scale up to. | string | n/a | yes |
| min\_replicas | The minimum number of replicas that the autoscaler can scale down to. | string | n/a | yes |
| name | The name of the autoscaler | string | n/a | yes |
| project | Project this resource belongs to. | string | n/a | yes |
| target\_instance\_group | URL of the managed instance group that this autoscaler will scale. | string | n/a | yes |
| zone | The zone which further specifies the region. | string | n/a | yes |

## Output
none

## Links

- https://www.terraform.io/docs/providers/google/r/compute_autoscaler.html