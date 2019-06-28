
variable "alarm_actions" {
  description = "Action for when alarms go into and ALERT state"
  default = ["arn:aws:sns:us-east-1:433568766270:planx-csoc-alerts-for-bsd-security"]
}

variable "cwl_group" {
  description = "The CloudWatchLog group where filter are going to take place"
  default    = ""
}
