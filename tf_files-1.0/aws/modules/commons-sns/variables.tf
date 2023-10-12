variable "vpc_name" {}

variable "cluster_type" {
  default = "EKS"
}

variable "emails" {
  default = ["someone@uchicago.edu","someone@uchicago.edu"]
}

variable "topic_display" {
  default = "cronjob manitor"
}
