
variable "vpc_name" {}

variable "cluster_type" {
  default = "EKS"
}

variable "emails" {
  default = ["fauzi@uchicago.edu","fauzi@g.uchicago.edu"]
}

variable "topic_display" {
  default = "cronjob manitor"
}
