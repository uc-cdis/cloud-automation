# Google Project
This terraform module provisions GCP projects under a specified folder.

## Usage
This module will create a new project under a specified folder. The project will default to creating the default network. The module will accept a list of APIs to enable for the project. A billing account must be provided.

### Optional
The module has a resource to bind the GCE generic service account from the CSOC account. This is used to allow admins from the CSOC to have operational access to GKE. The default is to not enable this option.

## Usage Example
Here's an example of passing in desired APIs for a new project under a specific folder.
```terraform
module "project" {
  source                      = "../../../modules/project"
  organization                = "organizations/1234567890"
  project_name                = "my-project"
  folder_id                   = "Development"
  region                      = "us-central1"
  billing_account             = "1234-1234-1234-1234"

  activate_apis = [
    "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "containerregistry.googleapis.com",
    "storage-api.googleapis.com",
    "servicenetworking.googleapis.com",
  ]
}
```
Here's an example of passing in the CSOC project id to the module to bind the GCE generic service account from the CSOC and bind it to this project. This gives admins from the CSOC access to GKE.
```terraform
module "project" {
  source                      = "../../../modules/project"
  organization                = "organizations/1234567890"
  project_name                = "my-project"
  folder_id                   = "Development"
  region                      = "us-central1"
  billing_account             = "1234-1234-1234-1234"

  add_csoc_service_account = true
  csoc_project_id          = "9876543210"

  activate_apis = [
    "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "containerregistry.googleapis.com",
    "storage-api.googleapis.com",
    "servicenetworking.googleapis.com",
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| activate\_apis | The list of apis to activate within the project | list | n/a | yes |
| add\_csoc\_service\_account | Add the auto-created service account from the csoc to GKE viewer role. | string | `"false"` | no |
| auto\_create\_network | Create the 'default' network automatically. | string | `"true"` | no |
| billing\_account | Every working projects needs a billing account associated to it. Assign billing account. | string | n/a | yes |
| csoc\_project\_id | Project ID that lives in the csoc. Must be changed if 'add_csoc_service_account' is set to true. | string | `"1234567890"` | no |
| disable\_services\_on\_destroy | Whether project services will be disabled when the resources are destroyed. https://www.terraform.io/docs/providers/google/r/google_project_service.html#disable_on_destroy | string | `"true"` | no |
| enable\_apis | Whether to actually enable the APIs. If false, this module is a no-op. | string | `"true"` | no |
| folder\_id | Name of the folder to place project underneath. | string | n/a | yes |
| organization | Org_Id | string | n/a | yes |
| project\_name | Name of the project. | string | n/a | yes |
| region | Region the project will be based out of. | string | n/a | yes |
| set\_parent\_folder | Whether to create the project in the org root or in a folder | string | `"true"` | no |

## Outputs

| Name | Description |
|------|-------------|
| project\_apis | Project enabled APIs |
| project\_id | Project ID |
| project\_name | Project name |
| project\_number | Project number |