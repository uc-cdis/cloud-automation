variable "vpc_name" {}

variable "hostname" {
  # DNS endpoint of the commons - ex: data.commons.io
}

variable "kube_bucket_name" {
  # utility bucket used for config backups or whatever
  default = ""
}

variable "logs_bucket_name" {
  # destination for load-balancer logs
  default = ""
}

variable "ssl_certificate_id" {
  # AWS cert manager ARN on AWS,
  # not sure what applies elsewhere
  default = "AWS-CERTIFICATE-ID"
}

# legacy oauth client setup for sheepdog as an oauth client to fence
variable "sheepdog_oauth2_client_id" {
  default = "deprecated"
}

variable "sheepdog_oauth2_client_secret" {
  default = "deprecated"
}

variable "sheepdog_indexd_password" {
  # indexd basic-auth password for `sheepdog` indexd user
}

variable "sheepdog_secret_key" {
  # FLASK_SECRET_KEY thing - don't know why we have flask sessions
}

variable "hmac_encryption_key" {
  # HMAC API access deprecated
  default = "deprecated"
}

variable "google_client_id" {
  # OAUTH client id for Google - allows "Login with Google"
}

variable "google_client_secret" {}

variable "db_fence_name" {
  # legacy commons might carry forward `userapi` names
  default = "fence"
}

variable "db_fence_password" {}

variable "db_fence_username" {
  # legacy commons might carry forward `userapi` names
  default = "fence_user"
}

variable "db_fence_address" {}

variable "db_indexd_name" {
  default = "indexd"
}

variable "db_indexd_password" {}

variable "db_indexd_username" {
  default = "indexd_user"
}

variable "db_indexd_address" {}

variable "db_sheepdog_password" {
  # password for sheepdog user to shared sheepdog db
}

variable "db_peregrine_password" {
  # password for peregrine user to shared sheepdog db
}

variable "db_sheepdog_username" {
  default = "sheepdog"
}

variable "db_sheepdog_name" {
  default = "sheepdog"
}

variable "db_sheepdog_address" {}

variable "db_peregrine_address" {}


variable "aws_user_key" {}

variable "aws_user_key_id" {}

variable "indexd_prefix" {}

## Mailgun variable defaults/definitions.
variable "mailgun_api_key" {}

variable "mailgun_smtp_host" {
  default = "smtp.mailgun.org"
}

variable "mailgun_api_url" {
  default = "https://api.mailgun.net/v3/"
}

variable "gitops_path" {
  default = "https://github.com/uc-cdis/cdis-manifest.git"
}