# VPC_Peering

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
