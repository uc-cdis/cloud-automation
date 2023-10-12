resource "aws_cloudwatch_event_rule" "event_rule" {
  name          = var.cwe_rule_name
  description   = var.cwe_rule_description
  event_pattern = var.cwe_rule_pattern
}

resource "aws_cloudwatch_event_target" "sns" {
  rule = aws_cloudwatch_event_rule.event_rule.name
  arn  = var.cwe_target_arn
}
