variable sqs_name {
  default = ""
  type = string
  description = "The name of the SQS queue to stand up"
}

variable slack_webhook {
  default = ""
  type = string
  description = "The URL for a webhook to send alerts to Slack"
}

variable role_name{
  default = ""
  type = string
  description = "The name of the role to be created"
}

variable role_tags{
  default = {}
  type = map
  description = "Tags for the role"
}

variable role_force_detach_policies {
  default = "false"
  type = string
  description = "Specifies to force detaching any policies the role has before destroying it. Defaults to false."
}

variable role_description {
  default = ""
  type = string
  description = "A description for the role"
}

variable policy_name {
  default = ""
  type = string
  description = "Name for the IAM policy to be associated with the SQS queue"
}

variable policy_path {
  default = ""
  type = string
  description = "Path in which to create the policy."
}

variable policy_description {
  default = ""
  type = string
  description = "Description for the policy"
}

variable provider_arn {
  default = ""
  type = string
  description = "The ARN for the OIDC provider for the cluster audit is to live in. This is expected to be provided by the getAWSInfo script"
}

variable issuer_url {
  default = ""
  type = string
  description = "The URL of the OIDC provider for the cluster audit is to live in. This is expected to be provided by the getAWSInfo script"
}

variable namespace {
  default = ""
  type = string
  description = "The namespace in which is audit is to live. This is expected to be provided by the getAWSInfo script"
}

variable  service_account{
  default = "audit-service-sa"
  type = string
  description = "The service account audit will use to connect with SQS. This account will be granted the permission to assume a role that can access the queue."
}