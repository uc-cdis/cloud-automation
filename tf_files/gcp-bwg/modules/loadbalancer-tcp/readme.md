# Internal Load Balancer Terraform Module

Modular Internal Load Balancer for GCE using forwarding rules.

## Usage

```terraform
module "gce-ilb" {
  source         = "GoogleCloudPlatform/lb-internal/google"
  region         = "${var.region}"
  name           = "group2-ilb"
  ports          = ["${module.mig2.service_port}"]
  health_port    = "${module.mig2.service_port}"
  source_tags    = ["${module.mig1.target_tags}"]
  target_tags    = ["${module.mig2.target_tags}","${module.mig3.target_tags}"]
  backends       = [
    { group = "${module.mig2.instance_group}" },
    { group = "${module.mig3.instance_group}" },
  ]
}
```
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| backends | List of backends, should be a map of key-value pairs for each backend, mush have the 'group' key. | list | n/a | yes |
| firewall\_project | Name of the project to create the firewall rule in. Useful for shared VPC. Default is var.project. | string | `""` | no |
| health\_port | Port to perform health checks on. | string | n/a | yes |
| http\_health\_check | Set to true if health check is type http, otherwise health check is tcp. | string | `"false"` | no |
| ip\_address | IP address of the internal load balancer, if empty one will be assigned. Default is empty. | string | `""` | no |
| ip\_protocol | The IP protocol for the backend and frontend forwarding rule. TCP or UDP. | string | `"TCP"` | no |
| load\_balancing\_scheme |  | string | `"INTERNAL"` | no |
| name | Name for the forwarding rule and prefix for supporting resources. | string | n/a | yes |
| network | Name of the network to create resources in. | string | `"default"` | no |
| ports | List of ports range to forward to backend services. Max is 5. | list | n/a | yes |
| project | The project to deploy to, if not set the default provider project is used. | string | n/a | yes |
| protocol | An optional list of ports to which this rule applies.Options tcp,udp,icmp,esp,ah,sctp | string | `"TCP"` | no |
| region | Region for cloud resources. | string | `"us-central1"` | no |
| session\_affinity | How to distribute load. Options are `NONE`, `CLIENT_IP` and `CLIENT_IP_PROTO` | string | `"NONE"` | no |
| source\_ranges | If source ranges are specified, the firewall will apply only to traffic that has source IP address in these ranges. These ranges must be expressed in CIDR format | list | `<list>` | no |
| subnetwork | Name of the subnetwork to create resources in. | string | `"default"` | no |
| target\_tags | List of target tags to allow traffic using firewall rule. | list | `<list>` | no |

## Outputs

| Name | Description |
|------|-------------|
| ip\_address | The ip address of the forwarding rule. |
