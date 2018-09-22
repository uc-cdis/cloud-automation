#####
#
# Module to create a sns topic with basic subcriptions
#
# fauzi@uchicago.edu
#
#####



#Basics

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


## Firstly, since pod within a kubernetes cluster will be the ones calling aws api to communicate with 
## the SNS topic, we are going to modify its role to allow access to SNS

# let's find the role first
data "aws_iam_role" "workers_role" {
  name = "${var.cluster_type == "EKS" ? replace("eks_VPC_workers_role","VPC",var.vpc_name) :  replace(replace("REGION-VPC-worker","VPC",var.vpc_name),"REGION",data.aws_region.current.name)}"
}

# Attach policies for said role
resource "aws_iam_role_policy_attachment" "sns-access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
  role       = "${aws_iam_role.workers_role.name}"
}


resource "aws_sns_topic" "user_updates" {
  count = "${length(var.emails)}"
  name  = "${var.vpc_name}-user-updates-topic"
  display_name = "${var.topic_display}"
  provisioner "local-exec" {
    command = "aws sns subscribe --topic-arn ${self.arn} --protocol email --notification-endpoint ${var.emails[count.index]}"
  }
}


