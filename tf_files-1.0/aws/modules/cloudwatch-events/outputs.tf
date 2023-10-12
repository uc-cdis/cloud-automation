output "event_rule" {
  value = aws_cloudwatch_event_rule.event_rule.name
}

output "event_arn" {
  value = aws_cloudwatch_event_rule.event_rule.arn
}
