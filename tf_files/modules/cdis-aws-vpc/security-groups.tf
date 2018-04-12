resource "aws_security_group" "local" {
  name        = "local"
  description = "security group that only allow internal tcp traffics"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["172.24.${var.vpc_octet}.0/20", "${var.csoc_cidr}"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    # 54.224.0.0/12 logs.us-east-1.amazonaws.com
    cidr_blocks = ["172.24.${var.vpc_octet}.0/20", "54.224.0.0/12"]
  }

  tags {
    Environment  = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}

resource "aws_security_group" "webservice" {
  name        = "webservice"
  description = "security group that only allow internal tcp traffics"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["172.24.${var.vpc_octet}.0/20", "${var.csoc_cidr}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["172.24.${var.vpc_octet}.0/20"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Environment  = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}

resource "aws_security_group" "out" {
  name        = "out"
  description = "security group that allow outbound traffics"
  vpc_id      = "${aws_vpc.main.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Environment  = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}

resource "aws_security_group" "proxy" {
  name        = "squid-proxy"
  description = "allow inbound tcp at 3128"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 0
    to_port     = 3128
    protocol    = "TCP"
    cidr_blocks = ["172.24.${var.vpc_octet}.0/20", "${var.csoc_cidr}"]
  }

  tags {
    Environment  = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}
