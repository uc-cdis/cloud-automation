provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
}

resource "aws_vpc" "main" {
    cidr_block = "172.16.0.0/16"
    enable_dns_hostnames = true
    tags {
        Name = "${var.vpc_name}"
    }
}

resource "aws_internet_gateway" "gw" {
    vpc_id = "${aws_vpc.main.id}"

    tags {
        Name = "main"
    }
}

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
}

resource "aws_security_group" "local" {
  name = "local"
  description = "security group that only allow internal tcp traffics"
  vpc_id = "${aws_vpc.main.id}"
  ingress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["172.16.0.0/16"]
  }
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["172.16.0.0/16"]
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
      cidr_blocks = ["172.16.0.0/16"]
  }
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["172.16.0.0/16"]
  }
  egress {
      from_port = 443
      to_port = 443
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
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
}

resource "aws_security_group" "proxy" {
  name = "squid-proxy"
  description = "allow inbound tcp at 3128"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
      from_port = 0
      to_port = 3128
      protocol = "TCP"
      cidr_blocks = ["172.16.0.0/16"]
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
    }
}

resource "aws_eip" "nat" {
    vpc = true
}

resource "aws_nat_gateway" "gw" {
    allocation_id = "${aws_eip.nat.id}"
    subnet_id     = "${aws_subnet.public.id}"
}

resource "aws_route_table" "private" {
    vpc_id = "${aws_vpc.main.id}"
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = "${aws_nat_gateway.gw.id}"
    }
    tags {
        Name = "private"
    }
}

resource "aws_route_table" "private_2" {
    vpc_id = "${aws_vpc.main.id}"

    tags {
        Name = "private_2"
    }
}
resource "aws_route_table_association" "public" {
    subnet_id = "${aws_subnet.public.id}"
    route_table_id = "${aws_route_table.public.id}"
}


resource "aws_route_table_association" "private" {
    subnet_id = "${aws_subnet.private.id}"
    route_table_id = "${aws_route_table.private.id}"
}

resource "aws_route_table_association" "private_2" {
    subnet_id = "${aws_subnet.private_2.id}"
    route_table_id = "${aws_route_table.private_2.id}"
}

resource "aws_subnet" "public" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "172.16.0.0/24"
    map_public_ip_on_launch = true
    tags {
        Name = "public"
    }
}

resource "aws_subnet" "private" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "172.16.16.0/20"
    availability_zone = "${data.aws_availability_zones.available.names[0]}"
    map_public_ip_on_launch = false 
    tags {
        Name = "private"
    }
}

resource "aws_subnet" "private_2" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "172.16.4.0/22"
    map_public_ip_on_launch = false
    tags {
        Name = "private_2"
    }
}

resource "aws_subnet" "private_3" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "172.16.8.0/21"
    availability_zone = "${data.aws_availability_zones.available.names[1]}"
    map_public_ip_on_launch = false
    tags {
        Name = "private_3"
    }
}

resource "aws_db_subnet_group" "private_group" {
    name = "private_group"
    subnet_ids = ["${aws_subnet.private.id}", "${aws_subnet.private_3.id}"]

    tags {
        Name = "Private subnet group"
    }
    description = "Private subnet group"
}

resource "aws_instance" "login" {
    ami = "${var.login_ami}"
    subnet_id = "${aws_subnet.public.id}"
    instance_type = "t2.micro"
    monitoring = true
    vpc_security_group_ids = ["${aws_security_group.ssh.id}", "${aws_security_group.local.id}"]
    tags {
        Name = "Login Node"
    }
}

resource "aws_db_instance" "db_userapi" {
    allocated_storage    = "${var.db_size}"
    identifier           = "userapidb"
    storage_type         = "gp2"
    engine               = "postgres"
    engine_version       = "9.5.6"
    instance_class       = "${var.db_instance}"
    name                 = "${var.db_name}_userapi"
    username             = "userapi_user"
    password             = "${var.db_password_userapi}"
    db_subnet_group_name = "${aws_db_subnet_group.private_group.id}"
    vpc_security_group_ids = ["${aws_security_group.local.id}"]
}

resource "aws_db_instance" "db_gdcapi" {
    allocated_storage    = "${var.db_size}"
    identifier           = "gdcapidb"
    storage_type         = "gp2"
    engine               = "postgres"
    engine_version       = "9.5.6"
    instance_class       = "${var.db_instance}"
    name                 = "${var.db_name}_gdcapi"
    username             = "gdcapi_user"
    password             = "${var.db_password_gdcapi}"
    db_subnet_group_name = "${aws_db_subnet_group.private_group.id}"
    vpc_security_group_ids = ["${aws_security_group.local.id}"]
}

resource "aws_db_instance" "db_indexd" {
    allocated_storage    = "${var.db_size}"
    identifier           = "indexddb"
    storage_type         = "gp2"
    engine               = "postgres"
    engine_version       = "9.5.6"
    instance_class       = "${var.db_instance}"
    name                 = "${var.db_name}_indexd"
    username             = "indexd_user"
    password             = "${var.db_password_indexd}"
    db_subnet_group_name = "${aws_db_subnet_group.private_group.id}"
    vpc_security_group_ids = ["${aws_security_group.local.id}"]
}

data "template_file" "creds" {
    template = "${file("creds.tpl")}"
    vars {
        userapi_host = "${aws_db_instance.db_userapi.address}"
        userapi_user = "${aws_db_instance.db_userapi.username}"
        userapi_pwd = "${aws_db_instance.db_userapi.password}"
        userapi_db = "${aws_db_instance.db_userapi.name}"
        gdcapi_host = "${aws_db_instance.db_gdcapi.address}"
        gdcapi_user = "${aws_db_instance.db_gdcapi.username}"
        gdcapi_pwd = "${aws_db_instance.db_gdcapi.password}"
        gdcapi_db = "${aws_db_instance.db_gdcapi.name}"
        indexd_host = "${aws_db_instance.db_indexd.address}"
        indexd_user = "${aws_db_instance.db_indexd.username}"
        indexd_pwd = "${aws_db_instance.db_indexd.password}"
        indexd_db = "${aws_db_instance.db_indexd.name}"
    }
}

resource "aws_instance" "kube_provisioner" {
    ami = "${var.login_ami}"
    subnet_id = "${aws_subnet.private.id}"
    instance_type = "t2.micro"
    monitoring = true
    vpc_security_group_ids = ["${aws_security_group.local.id}"]
    tags {
        Name = "Kube Provisioner"
    }
    provisioner "file" {
        content = "${data.template_file.creds.rendered}"
        destination = "/home/ubuntu/creds.json"
    }
    provisioner "file" {
        source = "script-kube.sh"
        destination = "/home/ubuntu/provisioning.sh"
    }
}

data "template_file" "reverse_proxy" {
    template = "${file("api_reverse_proxy.conf")}"
    vars {
        host_name = "${var.host_name}"
    }
}

resource "aws_instance" "reverse_proxy" {
    ami = "${var.login_ami}"
    subnet_id = "${aws_subnet.public.id}"
    instance_type = "t2.micro"
    monitoring = true
    vpc_security_group_ids = ["${aws_security_group.webservice.id}"]
    tags {
        Name = "Reverse proxy"
    }
}

resource "aws_instance" "proxy" {
    ami = "${var.proxy_ami}"
    subnet_id = "${aws_subnet.public.id}"
    instance_type = "t2.micro"
    monitoring = true
    vpc_security_group_ids = ["${aws_security_group.proxy.id}","${aws_security_group.login-ssh.id}", "${aws_security_group.out.id}"]
    tags {
        Name = "HTTP Proxy"
    }
}

resource "aws_route53_zone" "main" {
    name = "internal.io"
    comment = "internal dns server"
    vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route53_record" "www" {
    zone_id = "${aws_route53_zone.main.zone_id}"
    name = "cloud-proxy"
    type = "A"
    ttl = "300"
    records = ["${aws_instance.proxy.private_ip}"]
}
