## Complete VPC Peering Example
Configuration in this directory creates a VPC peering between the CSOC project and a Commons project.

Data sources are used to discover existing VPC names.

## Usage
To run this example you need to execute
```terraform
$ terraform init
$ terraform plan
$ terraform apply
```
Run terraform destroy when you don't need these resources.

## Inputs
| Name               | Description                                                                      | Type   | Default     | Required |
|--------------------|----------------------------------------------------------------------------------|--------|-------------|----------|
| region             | Region the project is located in                                                 | String | us-central1 | yes      |
| credential_file    | Location of the credential file.                                                 | String | -           | yes      |
| commons_vpc_name   | The   name   of   the   VPC   network   in   the   commons   project.            | String | -           | yes      |
| commons_project_id | The   ID   of   the   Commons   project   in   which   the   resource   belongs. | String | -           | yes      |
| csoc_vpc_name      | The   name   of   the   network   in   the   CSOC   project.                     | String | -           | yes      |
| csoc_project_id    | The   ID   of   the   CSOC   project   in   which   the   resource   belongs.    | String | -           | yes      |

## Outputs
| Name                | Description                                                                                                   |
|---------------------|---------------------------------------------------------------------------------------------------------------|
| peer1_state_details | Outputs the data and time of the VPC peer was created and if the the peer is connected from the commons side. |
| peer1_vpc_state     | Outputs that state of the peer on the commons side. Will display as either ACTIVE or INACTIVE.                |
| peer2_state_details | Outputs the data and time of the VPC peer was created and if the the peer is connected from the csoc side.    |
| peer2_vpc_state     | Outputs that state of the peer on the csoc side. Will display as either ACTIVE or INACTIVE.                   |