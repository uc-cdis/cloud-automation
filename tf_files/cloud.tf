provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
}

resource "aws_vpc" "main" {
    cidr_block = "172.16.0.0/16"
    enable_dns_hostnames = true
    tags {
        Name = "${var.vpc_name}"
        Environment = "${var.vpc_name}"
    }
}

resource "aws_internet_gateway" "gw" {
    vpc_id = "${aws_vpc.main.id}"
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
  tags {
    Environment = "${var.vpc_name}"
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
  }
}

resource "aws_security_group" "kube-worker" {
    name = "kube-worker"
    description = "security group that open ports to vpc, this needs to be attached to kube worker"
    vpc_id = "${aws_vpc.main.id}"
    ingress {
        from_port = 30000
        to_port = 30100
        protocol = "TCP"
        cidr_blocks = ["172.16.0.0/16"]
    }
    ingress {
        from_port = 443
        to_port = 443
        protocol = "TCP"
        cidr_blocks = ["${aws_instance.kube_provisioner.private_ip}/32"]
    }
    tags {
        Environment = "${var.vpc_name}"
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
  tags {
    Environment = "${var.vpc_name}"
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
  tags {
    Environment = "${var.vpc_name}"
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
    }
}

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_eip" "login" {
  vpc = true
}

resource "aws_eip" "revproxy" {
  vpc = true
}
resource "aws_eip_association" "login_eip" {
    instance_id = "${aws_instance.login.id}"
    allocation_id = "${aws_eip.login.id}"
}

resource "aws_eip_association" "revproxy_eip" {
    instance_id = "${aws_instance.reverse_proxy.id}"
    allocation_id = "${aws_eip.revproxy.id}"
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
        Environment = "${var.vpc_name}"
    }
}

resource "aws_route_table" "private_2" {
    vpc_id = "${aws_vpc.main.id}"

    tags {
        Name = "private_2"
        Environment = "${var.vpc_name}"
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
        Environment = "${var.vpc_name}"
    }
}

resource "aws_subnet" "private" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "172.16.16.0/20"
    availability_zone = "${data.aws_availability_zones.available.names[0]}"
    map_public_ip_on_launch = false 
    tags {
        Name = "private"
        Environment = "${var.vpc_name}"
    }
}

resource "aws_subnet" "private_2" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "172.16.4.0/22"
    map_public_ip_on_launch = false
    tags {
        Name = "private_2"
        Environment = "${var.vpc_name}"
    }
}

resource "aws_subnet" "private_3" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "172.16.8.0/21"
    availability_zone = "${data.aws_availability_zones.available.names[1]}"
    map_public_ip_on_launch = false
    tags {
        Name = "private_3"
        Environment = "${var.vpc_name}"
    }
}

resource "aws_db_subnet_group" "private_group" {
    name = "private_group"
    subnet_ids = ["${aws_subnet.private.id}", "${aws_subnet.private_3.id}"]

    tags {
        Name = "Private subnet group"
        Environment = "${var.vpc_name}"
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
        Environment = "${var.vpc_name}"
    }
}

resource "aws_db_instance" "db_userapi" {
    allocated_storage    = "${var.db_size}"
    identifier           = "${var.vpc_name}-userapidb"
    storage_type         = "gp2"
    engine               = "postgres"
    skip_final_snapshot  = true
    engine_version       = "9.5.6"
    instance_class       = "${var.db_instance}"
    name                 = "${var.vpc_name}_userapi"
    username             = "userapi_user"
    password             = "${var.db_password_userapi}"
    db_subnet_group_name = "${aws_db_subnet_group.private_group.id}"
    vpc_security_group_ids = ["${aws_security_group.local.id}"]
    tags {
        Environment = "${var.vpc_name}"
    }
}

resource "aws_db_instance" "db_gdcapi" {
    allocated_storage    = "${var.db_size}"
    identifier           = "${var.vpc_name}-gdcapidb"
    storage_type         = "gp2"
    engine               = "postgres"
    skip_final_snapshot  = true
    engine_version       = "9.5.6"
    instance_class       = "${var.db_instance}"
    name                 = "${var.vpc_name}_gdcapi"
    username             = "gdcapi_user"
    password             = "${var.db_password_gdcapi}"
    db_subnet_group_name = "${aws_db_subnet_group.private_group.id}"
    tags {
        Environment = "${var.vpc_name}"
    }   vpc_security_group_ids = ["${aws_security_group.local.id}"]
}

resource "aws_db_instance" "db_indexd" {
    allocated_storage    = "${var.db_size}"
    identifier           = "${var.vpc_name}-indexddb"
    storage_type         = "gp2"
    engine               = "postgres"
    skip_final_snapshot  = true
    engine_version       = "9.5.6"
    instance_class       = "${var.db_instance}"
    name                 = "${var.vpc_name}_indexd"
    username             = "indexd_user"
    password             = "${var.db_password_indexd}"
    db_subnet_group_name = "${aws_db_subnet_group.private_group.id}"
    vpc_security_group_ids = ["${aws_security_group.local.id}"]
    tags {
        Environment = "${var.vpc_name}"
    }
}

data "template_file" "cluster" {
    template = "${file("configs/cluster.yaml")}"
    vars {
        cluster_name = "${var.vpc_name}"
        kms_key = "${aws_kms_key.kube_key.arn}"
        route_table_id = "${aws_route_table.private.id}"
        vpc_id ="${aws_vpc.main.id}"
        vpc_cidr = "${aws_vpc.main.cidr_block}"
        subnet_id = "${aws_subnet.private.id}"
        subnet_cidr = "${aws_subnet.private.cidr_block}"
        subnet_zone = "${aws_subnet.private.availability_zone}"
        nat_id = "${aws_nat_gateway.gw.id}"
        security_group_id = "${aws_security_group.kube-worker.id}"
        kube_additional_keys = "${var.kube_additional_keys}"
        hosted_zone = "${aws_route53_zone.main.id}"
    }
}
data "template_file" "creds" {
    template = "${file("configs/creds.tpl")}"
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
        hostname = "${var.hostname}"
        google_client_secret = "${var.google_client_secret}"
        google_client_id = "${var.google_client_id}"
        hmac_encryption_key = "${var.hmac_encryption_key}"
        gdcapi_indexd_password = "${var.gdcapi_indexd_password}"
    }
}

data "template_file" "kube_up" {
    template = "${file("configs/kube-up.sh")}"
    vars {
        vpc_name = "${var.vpc_name}"
        s3_bucket = "${var.kube_bucket}"
    }
}

data "template_file" "kube_services" {
    template = "${file("configs/kube-services.sh")}"
    vars {
        vpc_name = "${var.vpc_name}"
        s3_bucket = "${var.kube_bucket}"
    }
}
data "template_file" "aws_creds" {
    template = "${file("configs/aws_credentials")}"
    vars {
        access_key = "${var.aws_access_key}"
        secret_key = "${var.aws_secret_key}"
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
        Environment = "${var.vpc_name}"
    }
}

resource "null_resource" "config_setup" {
    provisioner "local-exec" {
        command = "mkdir ${var.vpc_name}_output; echo '${data.template_file.creds.rendered}' >${var.vpc_name}_output/creds.json"
    }

    provisioner "local-exec" {
        command = "echo \"${data.template_file.cluster.rendered}\" > ${var.vpc_name}_output/cluster.yaml"
    }
    provisioner "local-exec" {
        command = "echo \"${data.template_file.kube_up.rendered}\" > ${var.vpc_name}_output/kube-up.sh"
    }
    provisioner "local-exec" {
        command = "echo \"${data.template_file.kube_services.rendered}\" > ${var.vpc_name}_output/kube-services.sh"
    }
    provisioner "local-exec" {
        command = "echo \"${data.template_file.aws_creds.rendered}\" > ${var.vpc_name}_output/credentials"
    }
    provisioner "local-exec" {
        command = "echo '${data.template_file.reverse_proxy.rendered}' > ${var.vpc_name}_output/proxy.conf"
    }
    provisioner "local-exec" {
        command = "echo '${data.template_file.reverse_proxy_setup.rendered}' > ${var.vpc_name}_output/revproxy-setup.sh"
    }

}

data "template_file" "reverse_proxy" {
    template = "${file("configs/api_reverse_proxy.conf")}"
    vars {
        hostname = "${var.hostname}"
    }
}

data "template_file" "reverse_proxy_setup" {
    template = "${file("configs/revproxy-setup.sh")}"
    vars {
        hostname = "${var.hostname}"
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
        Environment = "${var.vpc_name}"
    }
    tags {
        Environment = "${var.vpc_name}"
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
        Environment = "${var.vpc_name}"
    }

}

resource "aws_route53_zone" "main" {
    name = "internal.io"
    comment = "internal dns server for ${var.vpc_name}"
    vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route53_record" "squid" {
    zone_id = "${aws_route53_zone.main.zone_id}"
    name = "cloud-proxy"
    type = "A"
    ttl = "300"
    records = ["${aws_instance.proxy.private_ip}"]
}

resource "aws_route53_record" "revproxy" {
    zone_id = "${aws_route53_zone.main.zone_id}"
    name = "revproxy"
    type = "A"
    ttl = "300"
    records = ["${aws_instance.reverse_proxy.private_ip}"]
}

resource "aws_route53_record" "kube_provisioner" {
    zone_id = "${aws_route53_zone.main.zone_id}"
    name = "kube"
    type = "A"
    ttl = "300"
    records = ["${aws_instance.kube_provisioner.private_ip}"]
}
resource "aws_kms_key" "kube_key" {
    description = "encryption/decryption key for kubernete"
    enable_key_rotation = true
    tags {
        Environment = "${var.vpc_name}"
    }
}

resource "aws_key_pair" "automation_dev" {
    key_name = "automation_dev"
    public_key = "${var.kube_ssh_key}"
}
resource "aws_s3_bucket" "kube_bucket" {
  bucket = "${var.kube_bucket}"
  acl    = "private"

  tags {
    Name        = "${var.kube_bucket}"
    Environment = "${var.vpc_name}"
  }
}
