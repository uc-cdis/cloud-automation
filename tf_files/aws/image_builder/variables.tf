variable "base_image"{
  description = "The base image"
  default     = "amazon-eks-node-1.21-*"
}

variable "image_version"{
  description = "The version of the image being updated"
  default     = "1.21"
}

variable "account_id"{
  description = "Account ID's where image will be available"
  default     = "433568766270"
}

variable "cron_schedule"{
  description = "Cron schedule to build AMI's"
  default     = "cron(0 0 ? * 2 *)"
}

