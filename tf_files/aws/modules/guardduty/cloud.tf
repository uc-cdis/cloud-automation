resource "aws_guardduty_detector" "guardduty" {
  enable = var.enable_guardduty
}

resource "aws_guardduty_member" "member" {
  count = length(var.aws_accounts_and_emails)
  depends_on         = [aws_guardduty_detector.guardduty]
  account_id         = var.aws_accounts_and_emails[count.index].account_id
  detector_id        = aws_guardduty_detector.guardduty.id
  email              = var.aws_accounts_and_emails[count.index].email
  invite             = true
  invitation_message = "Please accept guardduty invitation"
}
