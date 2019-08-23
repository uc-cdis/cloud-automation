# Terraform Module - Folders in Google
This Terraform module creates new folders in GCP with the appropriate prebuild GCP roles assigned to the folder.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| compute\_instance\_viewer\_folder\_binding | Read-only access to get and list Compute Engine resources, without being able to read the data stored on them. Role applied at folder level. | list | `<list>` | no |
| create\_folder | Decide whether or not we need to create folders | string | n/a | yes |
| display\_name | The folder’s display name. A folder’s display name must be unique amongst its siblings. | string | n/a | yes |
| kubernetes\_cluster\_viewer\_folder\_binding | Read-only access to Kubernetes Clusters. Role applied at folder level. | list | `<list>` | no |
| kubernetes\_engine\_viewer\_folder\_binding | Provides read-only access to GKE resources. Role applied at folder level. | list | `<list>` | no |
| log\_viewer\_folder\_binding | Provides access to view logs. Role applied at folder level. | list | `<list>` | no |
| parent\_folder | The name of the Organization in the form {organization_id} or organizations/{organization_id} | string | n/a | yes |
| service\_account\_creator\_folder\_level | Create and manage service accounts at folder level. | list | `<list>` | no |
| stackdriver\_monitoring\_viewer\_folder\_binding | Provides read-only access to get and list information about all monitoring data and configurations at the folder level. | list | `<list>` | no |

## Outputs

| Name | Description |
|------|-------------|
| folder\_create\_time | The time the folder was created. |
| folder\_id | The folder id of the folder being created. |
| folder\_name | The name of the folder being created. |
| parent\_folder | The name of the parent folder being created. |