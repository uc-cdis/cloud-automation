data "aws_iam_policy_document" "cluster_logging_cloudwatch" {
    statement {
        actions = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:GetLogEvents",
            "logs:PutLogEvents",
            "logs:DescribeLogGroups",
            "logs:DescribeLogStreams",
            "logs:PutRetentionPolicy" 
        ]
        effect = "Allow"
        resources = [ "*" ]
    }
}
