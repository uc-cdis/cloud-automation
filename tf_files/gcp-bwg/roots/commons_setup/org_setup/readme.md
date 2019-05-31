# Terraform Module - GCP VPC

Terraform module will create a Google Cloud Identity Folder under a Google Cloud Identity Organization.

## Documentation

Root module calls these modules.
* folders - creates the folder

### Usage

```terraform
data "google_organization" "org" {
  domain = "${var.organization}"
}

module "folder" {
  source       = "../modules/folders"
  parent_folder = "organizations/${data.google_organization.org.id}"
  display_name  = "${var.folderName}" 
}
```
## Example
* TODO: Complete Folder Example

## Known Issues/Limitations
* None known at this point.


## Inputs
| Name                     | Description                                                                                                                                                                    | Type   | Default     | Required |
|--------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------|-------------|----------|
| region                   | Google Cloud Region for provider initialization                                                                                                                                | String | -           | yes      |
| credential_file          | service account credential file for provider initialization                                                                                                                    | String | -           | yes      |
| domain                   | Google Cloud Identity Organization name to place folder in                                                                                                                     | String | -           | yes      |
| parent_folder            | Org ID or ORG/Folder ID of where to place this folder                                                                                                                          | String | -           | yes      |
| display_name             | The   ID   of   the   project   in   which   the   resource   belongs.                                                                                                         | String | -           | yes      |

### Outputs
| Name                 | Description |
|----------------------|-------------|
| folder               |             |
| folder_create_time   |             |
