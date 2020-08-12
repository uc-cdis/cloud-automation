
data "aws_ami" "public_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = "${var.slurm_cluster_image["search_criteria"]}"
  }

  filter {
    name   = "virtualization-type"
    values = "${var.slurm_cluster_image["virtualization-type"]}"
  }

  filter {
    name   = "root-device-type"
    values = "${var.slurm_cluster_image["root-device-type"]}"
  }

  owners   = "${var.slurm_cluster_image["aws_accounts"]}"
}

#
# This guy should only have access to Cloudwatch and nothing more
#
data "aws_iam_policy_document" "vm_policy_document" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:GetLogEvents",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutRetentionPolicy",
      "ec2:DescribeTags",
    ]

    effect    = "Allow"
    resources = ["*"]
  }
}


data "aws_iam_policy_document" "source_bucket_acccess" {
  count = length(var.source_buckets)
  statement {
    actions = [
      "s3:Get*",
      "s3:List*"
    ]
    effect    = "Allow"
    resources = ["arn:aws:s3:::${element(var.source_buckets,count.index)}", "arn:aws:s3:::${element(var.source_buckets,count.index)}/*"]
  }
}


data "aws_iam_policy_document" "output_bucket_access" {
  statement {
    actions   = ["*"]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.data_bucket.arn}", "${aws_s3_bucket.data_bucket.arn}/*"]
  }
}

data "aws_region" "current" {}

data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
