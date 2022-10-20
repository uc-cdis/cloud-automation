variable "ssh_key"{
  description = "ssh key to access the endpoint"
  default     = ""
}

variable "s3_bucket_name"{
  description = "s3 bucket name where sftp server will host data"
  default     = ""
}
