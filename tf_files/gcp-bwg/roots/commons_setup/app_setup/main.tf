#################################################################################
# Log Sink
#################################################################################

module "org_data_access" {
  source      = "../../../modules/stackdriver/org_sink"
  name        = "${var.data_access_sink_name}"
  org_id      = "${var.org_id}"
  destination = "${data.terraform_remote_state.csoc_app_setup.storage_bucket_data_access_name}"
  filter      = "${var.data_access_filter}"
}

module "org_activity" {
  source      = "../../../modules/stackdriver/org_sink"
  name        = "${var.activity_sink_name}"
  org_id      = "${var.org_id}"
  destination = "${data.terraform_remote_state.csoc_app_setup.storage_bucket_activity_name}"
  filter      = "${var.data_access_filter}"
}