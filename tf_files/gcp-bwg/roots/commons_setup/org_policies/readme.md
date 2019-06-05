# Terraform Module - Organization Policies in Google
This Terraform module configures organization wide policies and assigns groups, users or service accounts to predefined roles in GCP.

# Requirements
## Permissions
In order to execute this module, the Service Account you run must have the following permissions
* <b>Organization Policy Administrator</b> (<code>roles/orgpolicy.policyAdmin</code>) role.


## Documentation
Root module calls these other resource modules.
* set_org_policies - pass in a list of constraints to set at the organization level.
* set_iam_roles - pass in a list of groups, users, or service account to be applied to a predefined list of GCP roles.
* set_iam_externalIPaccess - This resource module enable the policy "Define allowed external IPs for VM instances and optionally pass in a list of virtual machines that are allowed to have an external IP address. 


## Usage
A full example is in the examples folder, but basic usage is as to pass in a list of roles that are desired to be enabled for the environment.

Providing an Organization ID, are required if you want to add user accounts to the roles. If you do not provide then the role is skipped and no accounts will be added.
```terraform
module "set_org_policies" {
  source = "../../modules/org/policies"

  org_id_org_policies = "${data.google_organization.org.id}"
  constraint          = "${var.constraint}"
}

module "set_iam_roles" {
  source = "../../modules/roles"

  org_iam_binding                           = "${data.google_organization.org.id}"
  org_administrator_org_binding             = "${var.org_administrator_org_binding}"
  org_viewer_org_binding                    = "${var.org_viewer_org_binding}"
  projects_viewer_org_binding               = "${var.projects_viewer_org_binding}"
  network_admin_org_binding                 = "${var.network_admin_org_binding}"
  all_projects_org_owner                    = "${var.all_projects_org_owner}"
  billing_account_admin                     = "${var.billing_account_admin}"
  billing_account_user                      = "${var.billing_account_user}"
  billing_account_viewer                    = "${var.billing_account_viewer}"
  log_viewer_org_binding                    = "${var.log_viewer_org_binding}"
  org_policy_viewer_org_binding             = "${var.org_policy_viewer_org_binding}"
  folder_viewer_org_binding                 = "${var.folder_viewer_org_binding}"
  stackdriver_monitoring_viewer_org_binding = "${var.stackdriver_monitoring_viewer_org_binding}"
}

module "set_iam_externalIPaccess" {
  source = "../../modules/org/externalIPaccess"

  org_id_org_externalIP    = "${data.google_organization.org.id}"
  org_iam_externalipaccess = "${var.org_iam_externalipaccess}"
}
```

## Variables
To control the module's behavior, change variable's values regarding the following:

<code><b>required</b></code>
* <code>organization</code> - The name of the organization in cloud identity.

<code><b>optional</b></code>
* <code> *_org_binding</code> - Are lists and set permissions for groups, invidiual users, or service accounts at the organization level which then propegate down to the folder, projects and resource levels. The appropriate list values are as follow:
  * ["groups:admins@example.com"] - setting permissions for a group.
  * ["user:user1@example.com"] - Sets permissions for a single user.
  * ["serviceAccount:service_account@<project>.iam.google.com"] - Sets permission for a service account.
* <code>org_iam_externalipaccessernal</code> - Allows specific virtual machines to have an external IP address. The formate must be as follows:
<code>projects/PROJECT_ID/zones/ZONE/instances/INSTANCE</code>. 
Example: <code>projects/my-project/zones/us-central1-c/instances/virtualmachine</code>


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| all\_projects\_org\_owner | All editor permissions for the following actions:Manage roles and permissions for a project and all resources within the project.Set up billing for a project. Role applied at organization level. | list | `<list>` | no |
| billing\_account\_admin | Provides access to see and manage all aspects of billing accounts. | list | `<list>` | no |
| billing\_account\_user | Provides access to associate projects with billing accounts. | list | `<list>` | no |
| billing\_account\_viewer | View billing account cost information and transactions. | list | `<list>` | no |
| constraint | The name of the Contraint policy to configure. | list | `<list>` | no |
| credential\_file | Credential file. | string | `"credentials.json"` | no |
| folder\_viewer\_org\_binding | Provides permission to get a folder and list the folders and projects below a resource. Role applied at organization level. | list | `<list>` | no |
| log\_viewer\_org\_binding | View logs for the entire organization. Role applied at organization level. | list | `<list>` | no |
| network\_admin\_org\_binding | Permissions to create, modify, and delete networking resources, except for firewall rules and SSL certificates. Role applied at organization level. | list | `<list>` | no |
| org\_administrator\_org\_binding | Access to administer all resources belonging to the organization. Top level access in GCP. | list | `<list>` | no |
| org\_iam\_binding | Organization ID of the cloud identity. | string | `""` | no |
| org\_iam\_externalipaccess | List of VMs that are allowed to have external IP addresses. | list | `<list>` | no |
| org\_id | GCP Organization ID | string | `""` | no |
| org\_id\_org\_externalIP | Organization ID. | string | `""` | no |
| org\_policy\_viewer\_org\_binding | Provides access to view Organization Policies on resources at the organization level. | list | `<list>` | no |
| org\_viewer\_org\_binding | Provides access to view an organization. | list | `<list>` | no |
| organization | The name of the Organization. | string | `""` | no |
| prefix |  | string | `"org_setup"` | no |
| prefix\_org\_setup |  | string | `"org_setup"` | no |
| prefix\_project\_setup |  | string | `"project_setup"` | no |
| projects\_viewer\_org\_binding | Get and list access for all resources at the organization level. Cannot edit projects. | list | `<list>` | no |
| region | The region the resources will be located. | string | `"us-central1"` | no |
| stackdriver\_monitoring\_viewer\_org\_binding | Provides read-only access to get and list information about all monitoring data and configurations at the organization level. | list | `<list>` | no |
| state\_bucket\_name |  | string | `"tf-state"` | no |
| terraform\_workspace |  | string | `"my-workspace"` | no |