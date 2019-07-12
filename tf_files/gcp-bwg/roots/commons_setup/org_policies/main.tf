data "google_organization" "org" {
  domain = "${var.organization}"
}

/*************************
 Update Org Policies
 ************************/

module "set_org_policies" {
  source = "../../../modules/org/policies"

  org_id_org_policies = "${data.google_organization.org.id}"
  constraint          = "${var.constraint}"
}

/*************************
 Update Roles
*************************/
module "set_iam_roles" {
  source = "../../../modules/roles"

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

/*************************
 Update External IP Address
*************************/
module "set_iam_externalIPaccess" {
  source = "../../../modules/org/externalIPaccess"

  org_id_org_externalIP    = "${data.google_organization.org.id}"
  org_iam_externalipaccess = "${var.org_iam_externalipaccess}"
}
