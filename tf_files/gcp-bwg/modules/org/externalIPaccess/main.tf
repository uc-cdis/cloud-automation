# Service Account requires role: Organization Policy Administrator

resource "google_organization_policy" "set_external_ip_access" {
  count = "${length(var.org_iam_externalipaccess) > 0 ? 1 : 0}"

  org_id     = "${var.org_id_org_externalIP}"
  constraint = "compute.vmExternalIpAccess"

  list_policy {
    allow {
      values = ["${var.org_iam_externalipaccess}"]
    }
  }
}
