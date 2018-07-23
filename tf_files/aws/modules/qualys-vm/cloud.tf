## Logging group for the qualys (Need to chceck on the logging)

resource "aws_cloudwatch_log_group" "csoc_log_group" {
  name              = "${var.vm_name}"
  retention_in_days = 1827

  tags {
    Environment  = "${var.vm_name}"
    Organization = "Basic Services"
  }
}

#------- IAM setup ---------------------

resource "aws_iam_role" "qualys-vm_role" {
  name = "${var.vm_name}_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

# These qualys VMs should only have access to Cloudwatch and nothing more (Need to check more)

data "aws_iam_policy_document" "qualys_policy_document" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:GetLogEvents",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutRetentionPolicy",
    ]

    effect    = "Allow"
    resources = ["*"]
  }

}

resource "aws_iam_role_policy" "qualys_policy" {
  name   = "${var.vm_name}_policy"
  policy = "${data.aws_iam_policy_document.qualys_policy_document.json}"
  role   = "${aws_iam_role.qualys-vm_role.id}"
}

resource "aws_iam_instance_profile" "qualys_profile" {
  name = "${var.vm_name}_qualys_role_profile"
  role = "${aws_iam_role.qualys-vm_role.id}"
}




# Security group to manage the inbound and outboud access for the qualys VM

resource "aws_security_group" "ssh" {
  name        = "ssh_${var.vm_name}"
  description = "security group that only enables ssh"
  vpc_id      = "${var.csoc_vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Environment  = "${var.vm_name}"
    Organization = "Basic Service"
  }
}

resource "aws_security_group" "local" {
  name        = "local_${var.vm_name}"
  description = "security group that only allow internal tcp traffics"
  vpc_id      = "${var.csoc_vpc_id}"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Environment = "${var.vm_name}"
  }
}




## Creating a new subnet for Qualys VM launch 

resource "aws_subnet" "qualys_pub" {
  vpc_id                  = "${var.csoc_vpc_id}"
  cidr_block              = "10.128.${var.env_vpc_octet3}.0/24"
  tags                    = "${map("Name", "${var.vm_name}_pub", "Organization", "Basic Service", "Environment", var.vm_name)}"
}


resource "aws_route_table_association" "qualys_pub" {
  subnet_id      = "${aws_subnet.qualys_pub.id}"
  route_table_id = "${var.qualys_pub_subnet_routetable_id}"
}


## Launching the Qualys VM


resource "aws_ami_copy" "qualys_ami" {
  name              = "${var.vm_name}"
  description       = "A copy of Qualys Virtual Scanner Appliance"
  source_ami_id     = "ami-5f2e6520"
  source_ami_region = "us-east-1"
  encrypted         = true

  tags {
    Name        = "cdis"
    Environment = "${var.vm_name}"
  }

  lifecycle {
    #
    # Do not force update when new ami becomes available.
    # We still need to improve our mechanism for tracking .ssh/authorized_keys
    # User can use 'terraform state taint' to trigger update.
    #
    ignore_changes = ["source_ami_id"]
  }
}


resource "aws_instance" "qualys" {
  ami                    = "${aws_ami_copy.qualys_ami.id}"
  subnet_id              = "${aws_subnet.qualys_pub.id}"
  instance_type          = "t2.large"
  monitoring             = true
  key_name               = "${var.ssh_key_name}"
  vpc_security_group_ids = ["${aws_security_group.ssh.id}", "${aws_security_group.local.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.qualys_profile.name}"
  associate_public_ip_address = true

  tags {
    Name        = "${var.vm_name}_CSOC"
    Environment = "${var.vm_name}"
  }

  lifecycle {
    ignore_changes = ["ami", "key_name"]
  }

  user_data = <<EOF
PERSCODE="${var.user_perscode}"
EOF
}
