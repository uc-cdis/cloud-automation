variable "gcp_region" {}

variable "db_fence_password" {}

variable "db_peregrine_password" {}

variable "db_sheepdog_password" {}

variable "db_indexd_password" {}

variable "authorized_cidr" {
  # network with db connect privileges - see https://serverfault.com/questions/831519/unable-to-connect-to-cloud-sql-from-a-gcp-vm-instance
}

variable "db_availability" {
  # see https://www.terraform.io/docs/providers/google/r/sql_database_instance.html
  default = "ZONAL"
}

variable "db_tier" {
  default = "db-f1-micro"
}

variable "db_version" {
  default = "POSTGRES_9_6"
}

// for tagging resources ...
variable "vpc_name" {
  //default = "Commons1"
}
