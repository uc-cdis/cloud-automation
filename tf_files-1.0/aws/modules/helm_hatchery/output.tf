output "role_arn" {
  value = aws_iam_role.hatchery-role.arn
}

output "policy_arn" {
  value = aws_iam_role.hatchery-policy.arn
}