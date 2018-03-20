# id of AWS account that owns the public AMI's
variable "ami_account_id" {
  # cdis-test
  default = "707767160287"
}

#pass on the environment name
variable "environment_name" {
  default="csoc_main"
}

variable "public_subnet_id" {
  default="subnet-da2c0a87"
}

# name of aws_key_pair ssh key to attach to VM's
variable "ssh_key_name" {
  default = "rarya_id_rsa"
}

variable "csoc_cidr" {
  default = "10.128.0.0/20"
}


variable "csoc_vpc_id" {
  default = "vpc-e2b51d99"
}


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