terraform {
  backend "s3" {
    encrypt = "true"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_vpc" "new_vpc" {
  cidr_block = "10.1.0.0/16"

  tags = {
    Organization = "gen3",
    description  = "Created by bucket-manifest job",
    job-id       = var.job_id,
    prefix       = var.prefix
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.new_vpc.id

  tags = {
    Organization = "gen3",
    description  = "Created by bucket-manifest job",
    job-id       = var.job_id
  }
}

resource "aws_subnet" "new_subnet" {
  vpc_id                  = aws_vpc.new_vpc.id
  map_public_ip_on_launch = true
  cidr_block              = "10.1.0.0/21"

  tags = {
    Organization = "gen3",
    description  = "Created by bucket-manifest job",
    job-id       = var.job_id
  }
}


resource "aws_route_table" "new_route" {
  vpc_id = aws_vpc.new_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Organization = "gen3",
    description  = "Created by bucket-manifest job",
    job-id       = var.job_id
  }
}

resource "aws_route_table_association" "new_association" {
  subnet_id      = aws_subnet.new_subnet.id
  route_table_id = aws_route_table.new_route.id
}

resource "aws_sqs_queue" "new_sqs_queue" {
  name                      = var.sqs_queue_name
  message_retention_seconds = 86400

  tags = {
    Organization = "gen3",
    description  = "Created by bucket-manifest job",
    job-id       = var.job_id
  }
}

resource "aws_batch_job_definition" "new_batch_job_definition" {
  name                 = var.batch_job_definition_name
  type                 = "container"
  container_properties = file("${var.container_properties}")
}

resource "aws_iam_role" "iam_instance_role" {
  name               = var.iam_instance_role
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
  path   = "/"
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
      "Resource": "${aws_sqs_queue.new_sqs_queue.arn}"
    }
  ]
}
EOF
  depends_on = [aws_sqs_queue.new_sqs_queue]
}


resource "aws_iam_role_policy_attachment" "ecs_instance_role" {
  role       = aws_iam_role.iam_instance_role.name
  policy_arn = aws_iam_policy.new_iam_policy.id
}


resource "aws_iam_instance_profile" "iam_instance_profile_role" {
  name = var.iam_instance_profile_role
  role = aws_iam_role.iam_instance_role.name
}

resource "aws_iam_role" "aws_batch_service_role" {
  name = var.aws_batch_service_role
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
  role       = aws_iam_role.aws_batch_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

resource "aws_security_group" "new_sg" {
  name   = var.aws_batch_compute_environment_sg
  vpc_id = aws_vpc.new_vpc.id

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

  tags = {
    Organization = "gen3",
    description  = "Created by bucket-manifest job",
    job-id       = var.job_id
  }
}

resource "aws_batch_compute_environment" "new_batch_compute_environment" {
  compute_environment_name = var.compute_environment_name
  service_role             = aws_iam_role.aws_batch_service_role.arn
  type                     = var.compute_type

  compute_resources {
    instance_role      = aws_iam_instance_profile.iam_instance_profile_role.arn
    instance_type      = var.instance_type
    max_vcpus          = var.max_vcpus
    min_vcpus          = var.min_vcpus
    security_group_ids = [aws_security_group.new_sg.id]
    ec2_key_pair       = var.ec2_key_pair
    subnets            = [aws_subnet.new_subnet.id]
    type               = var.compute_env_type
  }

  depends_on   = [aws_iam_role_policy_attachment.aws_batch_service_role]
}


resource "aws_batch_job_queue" "batch-job-queue" {
  name                 = var.batch_job_queue_name
  state                = "ENABLED"
  priority             = var.priority
  compute_environments = [aws_batch_compute_environment.new_batch_compute_environment.arn]
}

resource "aws_s3_bucket" "new_bucket" {
  bucket = var.output_bucket_name
}

resource "aws_s3_bucket_server_side_encryption_configuration" "new_bucket" {
  bucket = aws_s3_bucket.new_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
