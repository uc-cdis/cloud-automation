# Terraform Module Organization-level Logging Sink
Manages an organization-level logging sink.

Note that you must have the "Logs Configuration Writer" IAM role (<code>roles/logging.configWriter</code>) granted to the credentials used wtih terraform.

## Usage
This module will create an organization level log sink that can be sent to either a Google Cloud Storage bucket, PubSub topic, or a BigQuery dataset. The default is to send to a Cloud Storage bucket. The cloud storage bucket should already be present before using this module.

Once the log sink is created, GCP will create a managed service accoun that is associated with the sink. This service account needs to be granted write access to the configured destination. The default is to grant the service account the role of <code>storage.objectCreator</code>.

## Varify
Organizational log sinks are not visible from the UI. You must go to the API explorer to check. Below is the URL to check.

https://cloud.google.com/logging/docs/reference/v2/rest/v2/organizations.sinks/list


## Example
Example below will create a new stackdriver log named <b>data_access_logging</b> that's tied to the <code>org_id</code> of <b>123456789</b> and Cloud Bucket is where the logs will be written to.
```terraform
module "org_data_access" {
  source      = "../../../modules/stackdriver/org_sink"
  name        = "data_access_logging"
  org_id      = "123456789"
  destination = "storage.googleapis.com/[GCS_BUCKET]"
  filter      = "logName:data_access"
}
```
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| destination | Where logs are written to. | string | n/a | yes |
| destination\_api | Destination can be Cloud Storage bucket, a PubSub topic, a BigQuery dataset. Default to Cloud Storage. | string | `"storage.googleapis.com"` | no |
| filter | The filter to apply when exporting logs. | string | n/a | yes |
| name | The name of the logging sink. | string | n/a | yes |
| org\_id | The numeric ID of the organization to be exported to the sink. | string | n/a | yes |
| writer\_identity\_role | he identity associated with this sink. This identity must be granted write access to the configured destination. | string | `"roles/storage.objectCreator"` | no |

## Outputs

| Name | Description |
|------|-------------|
| log\_writer\_role | The log writer permission. |
| writer\_identity | The identity associated with this sink. |