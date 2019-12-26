
resource "aws_cloudwatch_log_group" "gwl_group" {
  name              = "/aws/lambda/${var.vpc_name}-gw-checks-lambda" #${aws_lambda_function.gw_checks.function_name}
  retention_in_days = 14
}

# get the private kube table id
data "aws_route_table" "private_kube_route_table" {
  vpc_id      = "${data.aws_vpc.the_vpc.id}"
  tags {
    Name = "private_kube"
  }
}

#get the internal zone id
data "aws_route53_zone" "vpczone" {
  name        = "internal.io."
  vpc_id      = "${data.aws_vpc.the_vpc.id}"
}

module "iam_role" {
  source                  = "../iam-role"
  role_name               = "${var.vpc_name}-gw-checks-lambda-role"
  role_description        = "Role for ${var.vpc_name}-gw-checks-lambda"
  role_tags               = { Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
  role_assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "with_resources" {
  statement {
    actions = [
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:ReplaceRoute",
      "route53:GetHostedZone",
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:route-table/${aws_route_table.eks_private.id}",
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:route-table/${data.aws_route_table.private_kube_route_table.id}",
      "arn:aws:route53:::hostedzone/${data.aws_route53_zone.vpczone.zone_id}"
    ]
  }
}

data "aws_iam_policy_document" "without_resources" {
  statement {
    actions = [
      "autoscaling:DescribeAutoScalingInstances",
      "route53:CreateHostedZone",
      "ec2:DescribeInstances",
      "route53:ListHostedZones",
      "ec2:DeleteNetworkInterface",
      "ec2:DisassociateRouteTable",
      "ec2:DescribeSecurityGroups",
      "ec2:AssociateRouteTable",
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "autoscaling:DescribeAutoScalingGroups",
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeRouteTables",
      "ec2:DescribeInstanceAttribute",
      "ec2:ModifyInstanceAttribute"
    ]
    effect = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_policy_resources" {
  name                  = "resources_acces"
  policy                = "${data.aws_iam_policy_document.with_resources.json}"
  role                  = "${module.iam_role.role_id}"
}

resource "aws_iam_role_policy" "lambda_policy_no_resources" {
  name                  = "no_resources_acces"
  policy                = "${data.aws_iam_policy_document.without_resources.json}"
  role                  = "${module.iam_role.role_id}"
}


module "iam_policy" {
  source             = "../iam-policy"
  policy_name        = "${var.vpc_name}-gw-checks-lambda-cwlg"
  policy_path        = "/"
  policy_description = "IAM policy for ${var.vpc_name}-gw-checks-lambda to access CWLG"
  policy_json        = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = "${module.iam_role.role_id}" # "${aws_iam_role.iam_for_lambda.name}"
  policy_arn = "${module.iam_policy.arn}" # "${aws_iam_policy.lambda_logging.arn}"
}


data "archive_file" "lambda_function" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "lambda_function_payload.zip"
}



resource "aws_lambda_function" "gw_checks" {
  filename      = "lambda_function_payload.zip"
  function_name = "${var.vpc_name}-gw-checks-lambda"
  role          = "${module.iam_role.role_arn}" # "${aws_iam_role.iam_for_lambda.arn}"
  handler       = "lambda_function.lambda_handler"
  timeout       = 45
  description   = "Checks for internet access from the worker nodes subnets"

  vpc_config {
    subnet_ids         = ["${aws_subnet.eks_private.*.id}"]
    security_group_ids = ["${aws_security_group.eks_nodes_sg.id}"]
  }

  tags {
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }


  source_code_hash = "${data.archive_file.lambda_function.output_base64sha256}"

  runtime = "python3.8"

  environment {
    variables = {
      vpc_name = "${var.vpc_name}",
      url_test = "${var.url_test}"
    }
  }
#  depends_on = ["aws_iam_role_policy_attachment.lambda_logs","aws_cloudwatch_log_group.gwl_group"]
  depends_on = ["aws_cloudwatch_log_group.gwl_group"]
}


/*
https://discuss.hashicorp.com/t/conditional-and-lists-for-a-variable/3368

module "lambda_function" {
  source    = "../lambda-function"
  with_vpc = true
  lambda_function_file = "${path.module}/lambda_function.py"
  lambda_function_name = "${var.vpc_name}-gw-checks-lambda"
  lambda_function_description = "Checks for internet access from the worker nodes subnets"
  lambda_function_iam_role_arn = "${module.iam_role.role_arn}"
  lambda_function_handler = "lambda_function.lambda_handler"
  lambda_function_runtime = "python3.8"
  lambda_function_timeout = 60
  lambda_function_tags  = {"Environment"  = "${var.vpc_name}", "Organization" = "${var.organization_name}" }
  lambda_function_env = { "vpc_name" = "${var.vpc_name}", "url_test" = "${var.url_test}" }
  lambda_subnets_id = ["${aws_subnet.eks_private.*.id}"]
  lambda_security_groups = ["${aws_security_group.eks_nodes_sg.id}"]
}
*/
  

resource "aws_cloudwatch_event_rule" "gw_checks_rule" {
  name                = "${var.vpc_name}-GW-checks-job"
  description         = "Check if the gateway is working every minute"
  schedule_expression = "rate(1 minute)"
  tags {
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = "${aws_cloudwatch_event_rule.gw_checks_rule.name}"
#  target_id = "SendToSNS"
  arn       = "${aws_lambda_function.gw_checks.arn}"
#  arn       = "${module.lambda_function.function_arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.gw_checks.function_name}"
#  function_name = "${module.lambda_function.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.gw_checks_rule.arn}"
}
