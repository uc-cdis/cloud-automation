resource "aws_iam_role_policy_attachment" "sns-access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
  role       = data.aws_iam_role.workers_role.name
}


resource "aws_sns_topic" "user_updates" {
  name         = "${var.vpc_name}-user-updates-topic"
  display_name = var.topic_display
}


resource "null_resource" "subscription" {
  count = length(var.emails)
  provisioner "local-exec" { 
    command = "aws sns subscribe --topic-arn ${aws_sns_topic.user_updates.arn} --protocol email --notification-endpoint ${var.emails[count.index]}"
  }
}
