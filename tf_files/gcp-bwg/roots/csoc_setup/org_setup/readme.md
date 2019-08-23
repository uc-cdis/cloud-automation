# Terraform Module - Organization Setup

Terraform module will create a Google Cloud Identity Folder under a Google Cloud Identity Organization. Then a new GCP project will be provisioned with required APIs enabled.

# Requirements
## Permissions
In order to execute this module, the Service Account you run must have the following permissions
* <b>Organization Administrator</b> (<code>roles/resourcemanager.organizationAdmin</code>) role.
* <b>Folder Creator</b> (<code>roles/resourcemanager.folders.create</code>) role.
* <b>Billing Account User</b> (<code>roles/billing.user</code>) role.

## Documentation

Root module calls these two modules.
* folders - This module creates the folder and an optional list of permissions to be applied at the folder level.
* project - This module creates the project under the folder.

### Usage

The example below shows creating a folder and setting the permissions at the folder level. Each variable in the folders module accepts lists so multiple groups, individual users, or service accounts can be added. Next the root module will create a project with the required APIs enabled.

```terraform
data "google_organization" "org" {
  domain = "${var.organization}"
}

module "folders" {
  source        = "../../../modules/folders"
  parent_folder = "organizations/${data.google_organization.org.id}"
  display_name  = "production"
  create_folder = "true"

  kubernetes_cluster_viewer_folder_binding = ["group:admins@example.com"]  
  stackdriver_monitoring_viewer_folder_binding = ["group:developers@example.com","group:admins@example.com"]
  service_account_creator_folder_level         = ["group:sa_admin@example.com"]
}

module "project" {
  source                      = "../../../modules/project"
  organization                = "organizations/${data.google_organization.org.id}"
  project_name                = "my-project"
  folder_id                   = "${module.folders.folder_id}"
  billing_account             = "987654321"
  enable_apis                 = "true"
  disable_services_on_destroy = "true"

  activate_apis = [
    "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "containerregistry.googleapis.com",
    "storage-api.googleapis.com",
  ]
}
```
## Variables
To control the module's behavior, change variable's values regarding the following:

<code><b>required</b></code>
* <code>organization</code> - The name of the organization in cloud identity.
* <code>org_id</code> - The ID of the organization.
* <code>billing_account</code> - The billing account to assign to a project.
* <code>credential_file</code> - The json file that contains the credentials.

<code><b>optional</b></code>

* <code>*_folder_binding</code> - Are lists and set permissions for groups, invidiual users, or service accounts at the folder level which then propegate down to the projects and resource levels. The appropriate list values are as follow:
  * ["groups:admins@example.com"] - setting permissions for a group.
  * ["user:user1@example.com"] - Sets permissions for a single user.
  * ["serviceAccount:service_account@<project>.iam.google.com"] - Sets permission for a service account.



## Known Issues/Limitations
* None known at this point.


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| billing\_account | The alphanumeric ID of the billing account this project belongs to. | string | `""` | yes |
| bucket\_name\_iam | The name of the bucket(s) it applies to. | list | `<list>` | no |
| cloud\_storage\_viewer | View objects in a bucket. | list | `<list>` | no |
| compute\_instance\_viewer\_folder\_binding | Read-only access to get and list Compute Engine resources, without being able to read the data stored on them. Role applied at folder level. | list | `<list>` | no |
| create\_folder |  | string | n/a | yes |
| credential\_file | The service account credeitial file. | string | `"credentials.json"` | yes |
| folder |  | string | `"Production"` | no |
| kubernetes\_cluster\_viewer\_folder\_binding | Read-only access to Kubernetes Clusters. Role applied at folder level. | list | `<list>` | no |
| kubernetes\_engine\_viewer\_folder\_binding | Provides read-only access to GKE resources. Role applied at folder level. | list | `<list>` | no |
| log\_viewer\_folder\_binding | Provides access to view logs. Role applied at folder level. | list | `<list>` | no |
| org\_id | The numeric ID of the organization this project belongs to. | string | `""` | yes |
| organization | The name of the Organization. | string | `""` | yes |
| prefix |  | string | `"org_setup"` | no |
| prefix\_org\_setup |  | string | `"org_setup"` | no |
| prefix\_project\_setup |  | string | `"project_setup"` | no |
| project\_name | Name of the GCP Project | string | `"my-first-project"` | no |
| region |  | string | `"us-central1"` | no |
| service\_account\_creator\_folder\_binding | Create and manage service accounts at folder level. | list | `<list>` | no |
| set\_parent\_folder |  | string | n/a | yes |
| stackdriver\_monitoring\_viewer\_folder\_binding | Provides read-only access to get and list information about all monitoring data and configurations at the folder level. | list | `<list>` | no |
| state\_bucket\_name |  | string | `"tf-state"` | no |
| terraform\_workspace | Default Terraform workspace name. | string | `"my-workspace"` | no |

## Outputs

| Name | Description |
|------|-------------|
| folder | The name of the folder being created. |
| folder\_create\_time | The time the folder was created. |
| folder\_id | The folder id that was created. |
| parent\_folder | The parent folder name. |
| project\_id | The project ID. |
| project\_name | The display name of the project. |
| project\_number |  |