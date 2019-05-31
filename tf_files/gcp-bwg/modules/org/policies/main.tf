# Service Account requires role: Organization Policy Administrator

resource "google_organization_policy" "set_organization_policies" {
  count      = "${length(var.constraint)}"
  org_id     = "${var.org_id_org_policies}"
  constraint = "${element(var.constraint, count.index)}"

  boolean_policy {
    enforced = "${var.iam_policy_boolean_policy}"
  }
}
