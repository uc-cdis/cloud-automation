variable "enable_guardduty" {
  default = false
}


variable "aws_accounts_and_emails" {
    type = list(object({
      account_id = number
      email = string
    }))
    default = [
      #{ account_id = , alias = "", email = "" }
    ]
}
