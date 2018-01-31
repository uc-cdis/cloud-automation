resource "aws_security_group" "ssh" {
  name = "ssh"
  description = "security group that only enables ssh"
  vpc_id = "${aws_vpc.main.id}"
  ingress {
      from_port = 22
      to_port = 22
      protocol = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Environment = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}

resource "aws_security_group" "login-ssh" {
  name = "login-ssh"
  description = "security group that only enables ssh from login node"
  vpc_id = "${aws_vpc.main.id}"
  ingress {
      from_port = 22
      to_port = 22
      protocol = "TCP"
      cidr_blocks = ["${aws_instance.login.private_ip}/32"]
  }
  tags {
    Environment = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}

resource "aws_security_group" "local" {
  name = "local"
  description = "security group that only allow internal tcp traffics"
  vpc_id = "${aws_vpc.main.id}"
  ingress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["172.${var.vpc_octet}.0.0/16"]
  }
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["172.${var.vpc_octet}.0.0/16"]
  }
  tags {
    Environment = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}

resource "aws_security_group" "webservice" {
  name = "webservice"
  description = "security group that only allow internal tcp traffics"
  vpc_id = "${aws_vpc.main.id}"
  ingress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["172.${var.vpc_octet}.0.0/16"]
  }
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["172.${var.vpc_octet}.0.0/16"]
  }
  ingress {
      from_port = 443
      to_port = 443
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Environment = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}


resource "aws_security_group" "out" {
  name = "out"
  description = "security group that allow outbound traffics"
  vpc_id = "${aws_vpc.main.id}"

  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Environment = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}

resource "aws_security_group" "proxy" {
  name = "squid-proxy"
  description = "allow inbound tcp at 3128"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
      from_port = 0
      to_port = 3128
      protocol = "TCP"
      cidr_blocks = ["172.${var.vpc_octet}.0.0/16"]
  }
  tags {
    Environment = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}
