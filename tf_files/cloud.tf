provider "aws" {
}

resource "aws_vpc" "main" {
    cidr_block = "172.16.0.0/16"
    enable_dns_hostnames = true
    tags {
        Name = "main"
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

resource "aws_route_table" "private" {
    vpc_id = "${aws_vpc.main.id}"

    tags {
        Name = "private"
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


resource "aws_subnet" "public" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "172.16.1.0/24"
    map_public_ip_on_launch = true
    tags {
        Name = "public"
    }
}

resource "aws_subnet" "private" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "172.16.16.0/20"
    map_public_ip_on_launch = false 
    tags {
        Name = "private"
    }
}

resource "aws_instance" "login" {
    ami = "ami-d05e75b8"
    subnet_id = "${aws_subnet.public.id}"
    instance_type = "t2.micro"
    key_name = "${var.key_name}"
    monitoring = true
    security_groups = ["${aws_security_group.ssh.id}", "${aws_security_group.out.id}"]
    tags {
        Name = "Login Node"
    }
    provisioner "file" {
        source = "./conf"
        destination = "/home/ubuntu"
        connection {
            type = "ssh"
            user = "ubuntu"
        }
    }
    provisioner "remote-exec" {
        script = "script"
        connection {
            type = "ssh"
            user = "ubuntu"
        }
    }
}

resource "aws_instance" "proxy" {
    ami = "ami-d05e75b8"
    subnet_id = "${aws_subnet.public.id}"
    instance_type = "t2.micro"
    key_name = "${var.key_name}"
    monitoring = true
    security_groups = ["${aws_security_group.local.id}","${aws_security_group.ssh.id}", "${aws_security_group.out.id}"]
    tags {
        Name = "HTTP Proxy"
    }
    provisioner "remote-exec" {
        inline = [
            "sudo apt-get update",
            "sudo apt-get -y install squid3"
        ]
        connection {
            type = "ssh"
            user = "ubuntu"
        }
    }
    provisioner "file" {
        source = "./conf/squid.conf"
        destination = "squid.conf"
        connection {
            type = "ssh"
            user = "ubuntu"
        }
    }
    provisioner "remote-exec" {
        inline = [
            "sudo mv squid.conf /etc/squid3/",
            "sudo service squid3 restart"
        ]
        connection {
            type = "ssh"
            user = "ubuntu"
        }

    }
}

resource "aws_instance" "test" {
    ami = "ami-d05e75b8"
    subnet_id = "${aws_subnet.private.id}"
    instance_type = "t2.micro"
    key_name = "${var.key_name}"
    monitoring = true
    security_groups = ["${aws_security_group.local.id}"]
    tags {
        Name = "test"
    }
}

resource "aws_route53_zone" "main" {
    name = "internal.com"
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
