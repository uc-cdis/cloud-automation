resource "aws_vpc" "main" {
    cidr_block = "172.${var.vpc_octet}.0.0/16"
    enable_dns_hostnames = true
    tags {
        Name = "${var.vpc_name}"
        Environment = "${var.vpc_name}"
        Organization = "Basic Service"
    }
}

data "aws_vpc_endpoint_service" "s3" {
    service = "s3"
}

resource "aws_vpc_endpoint" "private-s3" {
    vpc_id = "${aws_vpc.main.id}"
    #service_name = "com.amazonaws.us-east-1.s3"
    service_name = "${data.aws_vpc_endpoint_service.s3.service_name}"
    route_table_ids = ["${aws_route_table.private_user.id}"]
}

resource "aws_internet_gateway" "gw" {
    vpc_id = "${aws_vpc.main.id}"
    tags {
        Environment = "${var.vpc_name}"
        Organization = "Basic Service"
    }
}

resource "aws_route_table" "public" {
    vpc_id = "${aws_vpc.main.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.gw.id}"
    }

    tags {
        Name = "main"
        Environment = "${var.vpc_name}"
        Organization = "Basic Service"
    }
}

resource "aws_eip" "login" {
  vpc = true
}

resource "aws_eip_association" "login_eip" {
    instance_id = "${aws_instance.login.id}"
    allocation_id = "${aws_eip.login.id}"
}

resource "aws_route_table" "private_user" {
    vpc_id = "${aws_vpc.main.id}"

    tags {
        Name = "private_user"
        Environment = "${var.vpc_name}"
        Organization = "Basic Service"
    }
}
resource "aws_route_table_association" "public" {
    subnet_id = "${aws_subnet.public.id}"
    route_table_id = "${aws_route_table.public.id}"
}


resource "aws_route_table_association" "private_user" {
    subnet_id = "${aws_subnet.private_user.id}"
    route_table_id = "${aws_route_table.private_user.id}"
}

resource "aws_subnet" "public" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "172.${var.vpc_octet}.128.0/24"
    map_public_ip_on_launch = true
    tags = "${map("Name", "public", "Organization", "Basic Service", "Environment", var.vpc_name)}"
}


resource "aws_subnet" "private_user" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "172.${var.vpc_octet}.32.0/22"
    map_public_ip_on_launch = false
    tags {
        Name = "private_user"
        Environment = "${var.vpc_name}"
        Organization = "Basic Service"
    }
}


data "aws_ami" "public_login_ami" {
  most_recent      = true

  filter {
    name   = "name"
    values = ["ubuntu16-client-1.0.1-*"]
  }

  owners     = ["${var.ami_account_id}"]
}

data "aws_ami" "public_squid_ami" {
  most_recent      = true

  filter {
    name   = "name"
    values = ["ubuntu16-squid-1.0.1-*"]
  }

  owners     = ["${var.ami_account_id}"]
}

resource "aws_ami_copy" "login_ami" {
  name              = "ub16-client-crypt-${var.vpc_name}-1.0.0"
  description       = "A copy of ubuntu16-client-1.0.0"
  source_ami_id     = "${data.aws_ami.public_login_ami.id}"
  source_ami_region = "us-east-1"
  encrypted = true

  tags {
    Name = "login"
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

resource "aws_ami_copy" "squid_ami" {
  name              = "ub16-squid-crypt-${var.vpc_name}-1.0.0"
  description       = "A copy of ubuntu16-squid-1.0.0"
  source_ami_id     = "${data.aws_ami.public_squid_ami.id}"
  source_ami_region = "us-east-1"
  encrypted = true

  tags {
    Name = "login"
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


resource "aws_instance" "login" {
    ami = "${aws_ami_copy.login_ami.id}"
    subnet_id = "${aws_subnet.public.id}"
    instance_type = "t2.micro"
    monitoring = true
    vpc_security_group_ids = ["${aws_security_group.ssh.id}", "${aws_security_group.local.id}"]
    tags {
        Name = "${var.vpc_name} Login Node"
        Environment = "${var.vpc_name}"
        Organization = "Basic Service"
    }
    lifecycle {
        ignore_changes = ["ami"]
    }
}

resource "aws_instance" "proxy" {
    ami = "${aws_ami_copy.squid_ami.id}"
    subnet_id = "${aws_subnet.public.id}"
    instance_type = "t2.micro"
    monitoring = true
    source_dest_check = false
    vpc_security_group_ids = ["${aws_security_group.proxy.id}","${aws_security_group.login-ssh.id}", "${aws_security_group.out.id}"]
    tags {
        Name = "${var.vpc_name} HTTP Proxy"
        Environment = "${var.vpc_name}"
        Organization = "Basic Service"
    }
}

resource "aws_route53_zone" "main" {
    name = "internal.io"
    comment = "internal dns server for ${var.vpc_name}"
    vpc_id = "${aws_vpc.main.id}"
    tags {
        Environment = "${var.vpc_name}"
        Organization = "Basic Service"
    }
}

resource "aws_route53_record" "squid" {
    zone_id = "${aws_route53_zone.main.zone_id}"
    name = "cloud-proxy"
    type = "A"
    ttl = "300"
    records = ["${aws_instance.proxy.private_ip}"]
}
