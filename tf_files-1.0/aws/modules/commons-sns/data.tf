data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_role" "workers_role" {
  name = "${var.cluster_type == "EKS" ? replace("eks_VPC_workers_role","VPC",var.vpc_name) :  replace(replace("REGION-VPC-worker","VPC",var.vpc_name),"REGION",data.aws_region.current.name)}"
}