resource "aws_guardduty_detector" "guardduty" {
  enable = var.enable_guardduty
}