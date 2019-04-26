# Terraform Module - GCP VPC Peering

Terraform module which peers two projects in a Google Cloud. These two projects can be part of the same Organization ID, or different Organization ID. Projects in GCP are globally unique.

## Documentation

Root module calls these modules.
* vpc-peering - creates the VPC-peering

### Usage

```terraform
module "vpc_peering" {
  source = "../modules/vpc-peering"

  peer1_name = "commons-project-to-csoc-project"
  peer2_name = "csoc-project-to-commons-project"

  project_id      = "commons-unique-id"
  csoc_project_id = "csoc-unique-id"

  peer1_create_routes = "true"
  peer2_create_routes = "true"
}
```
## Example
* Complete VPC-Peering Example

## Known Issues/Limitations
* None known at this point.
* First time running, peer1_state_details may show Wainting for peer network to connect. Re-run and it will show as being Connected.
* First time running, peer1_vpc_state may show INACTIVE. Re-run and it show as being ACTIVE.

## Inputs
| Name                | Description                                                                                                                                          |  Type  | Default | Required |
|---------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|:------:|:-------:|:--------:|
| commons_vpc_name    | The   name   of   the   VPC   network   in   the   commons   project.                                                                                | String |    -    |    yes   |
| commons_project_id  | The   ID   of   the   Commons   project   in   which   the   resource   belongs.                                                                     | String |    -    |    yes   |
| csoc_vpc_name       | The   name   of   the   network   in   the   CSOC   project.                                                                                         | String |    -    |    yes   |
| csoc_project_id     | The   ID   of   the   CSOC   project   in   which   the   resource   belongs.                                                                        | String |    -    |    yes   |
| peer1_create_routes | If   set   to   true ,  the   routes   between   the   two   networks   will   be   created   and   managed   automatically.   Defaults   to   true. | String |   true  |    no    |
| peer2_create_routes | If   set   to   true ,  the   routes   between   the   two   networks   will   be   created   and   managed   automatically.   Defaults   to   true. | String |   true  |    no    |                                                                                                                                                  

### Outputs

| Name                | Description                                                                                                   |
|---------------------|---------------------------------------------------------------------------------------------------------------|
| peer1_state_details | Outputs the data and time of the VPC peer was created and if the the peer is connected from the commons side. |
| peer1_vpc_state     | Outputs that state of the peer on the commons side. Will display as either ACTIVE or INACTIVE.                |
| peer2_state_details | Outputs the data and time of the VPC peer was created and if the the peer is connected from the csoc side.    |
| peer2_vpc_state     | Outputs that state of the peer on the csoc side. Will display as either ACTIVE or INACTIVE.                   |