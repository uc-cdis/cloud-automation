# Security group to manage the inbound and outboud access for the qualys VM

resource "aws_security_group" "ssh" {
  name        = "ssh_${var.vm_name}"
  description = "security group that only enables ssh"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment  = "${var.environment}"
    Organization = "${var.organization}"
    Association  = "${var.vm_name}"
  }
}

resource "aws_security_group" "local" {
  name        = "local_${var.vm_name}"
  description = "security group that only allow internal tcp traffics"
  vpc_id      = "${var.vpc_id}"
 egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment  = "${var.environment}"
    Organization = "${var.organization}"
    Association  = "${var.vm_name}"
  }
}




## Creating a new subnet for Qualys VM launch 

resource "aws_subnet" "qualys_pub" {
  vpc_id                  = "${var.vpc_id}"
  cidr_block              = "${var.env_vpc_subnet}"
  tags                    = "${map("Name", "${var.vm_name}_pub", "Organization", var.organization, "Environment", var.environment, "Association", var.vm_name)}"
}


resource "aws_route_table_association" "qualys_pub" {
  subnet_id      = "${aws_subnet.qualys_pub.id}"
  route_table_id = "${var.qualys_pub_subnet_routetable_id}"
}


## Launching the Qualys VM

resource "aws_instance" "qualys" {
  ami                         = "${data.aws_ami.qualys_ami.id}"
  subnet_id                   = "${aws_subnet.qualys_pub.id}"
  instance_type               = "${var.instance_type}"
  monitoring                  = true
  key_name                    = "${var.ssh_key_name}"
  vpc_security_group_ids      = ["${aws_security_group.ssh.id}", "${aws_security_group.local.id}"]
  associate_public_ip_address = true
  disable_api_termination     = true

  tags = {
    Name         = "${var.vm_name}"
    Environment  = "${var.environment}"
    Organization = "${var.organization}"
  }

  lifecycle {
    ignore_changes = ["ami", "key_name"]
  }

user_data = <<EOF
PERSCODE=${var.user_perscode}
EOF
}
