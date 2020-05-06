terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}


resource "aws_batch_job_definition" "new_batch_job_definition" {
  name = "${var.batch_job_definition_name}"
  type = "container"

  container_properties = "${file("${var.container_properties}")}"
}

resource "aws_iam_role" "iam_instance_role" {
  name = "${var.iam_instance_role}"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
        "Service": "ec2.amazonaws.com"
        }
    }
    ]
}
EOF
}

resource "aws_iam_policy" "new_iam_policy" {
  name        = "test_policy"
  path        = "/"
  description = "My test policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
      "ec2:DescribeTags",
      "ecs:CreateCluster",
      "ecs:DeregisterContainerInstance",
      "ecs:DiscoverPollEndpoint",
      "ecs:Poll",
      "ecs:RegisterContainerInstance",
      "ecs:StartTelemetrySession",
      "ecs:UpdateContainerInstancesState",
      "ecs:Submit*",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "sqs:ListQueues",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "sqs:*",
      "Resource": "arn:aws:sqs:us-east-1:707767160287:terraform-example-queue"
    }
  ]
}
EOF
}


resource "aws_iam_role_policy_attachment" "ecs_instance_role" {
  role       = "${aws_iam_role.iam_instance_role.name}"
  policy_arn = "${aws_iam_policy.new_iam_policy.id}"
  #policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}


resource "aws_iam_instance_profile" "iam_instance_profile_role" {
  name = "${var.iam_instance_profile_role}"
  role = "${aws_iam_role.iam_instance_role.name}"
}

resource "aws_iam_role" "aws_batch_service_role" {
  name = "${var.aws_batch_service_role}"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
        "Service": "batch.amazonaws.com"
        }
    }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "aws_batch_service_role" {
  role       = "${aws_iam_role.aws_batch_service_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

resource "aws_security_group" "new_sg" {
  name = "${var.aws_batch_compute_environment_sg}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress{
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_batch_compute_environment" "new_batch_compute_environment" {
  compute_environment_name = "${var.compute_environment_name}"

  compute_resources {
    instance_role = "${aws_iam_instance_profile.iam_instance_profile_role.arn}"

    instance_type = "${var.instance_type}"

    max_vcpus = "${var.max_vcpus}"
    min_vcpus = "${var.min_vcpus}"

    security_group_ids = [
      "${aws_security_group.new_sg.id}",
    ]

    ec2_key_pair = "${var.ec2_key_pair}"


    subnets = "${var.subnets}"

    type = "${var.compute_env_type}"
  }

  service_role = "${aws_iam_role.aws_batch_service_role.arn}"
  type         = "${var.compute_type}"
  depends_on   = ["aws_iam_role_policy_attachment.aws_batch_service_role"]
}


resource "aws_batch_job_queue" "batch-job-queue" {
  name = "${var.batch_job_queue_name}"
  state                = "ENABLED"
  priority             = "${var.priority}"
  compute_environments = ["${aws_batch_compute_environment.new_batch_compute_environment.arn}"]
}


resource "aws_sqs_queue" "terraform_queue" {
  name                      = "terraform-example-queue"
  message_retention_seconds = 86400
}
