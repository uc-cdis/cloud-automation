
resource "aws_security_group" "kube-worker" {
    name = "kube-worker"
    description = "security group that open ports to vpc, this needs to be attached to kube worker"
    vpc_id = "${aws_vpc.main.id}"
    ingress {
        from_port = 30000
        to_port = 30100
        protocol = "TCP"
        cidr_blocks = ["172.${var.vpc_octet}.0.0/16"]
    }
    ingress {
        from_port = 443
        to_port = 443
        protocol = "TCP"
        cidr_blocks = ["${aws_instance.kube_provisioner.private_ip}/32"]
    }
    tags {
        Environment = "${var.vpc_name}"
        Organization = "Basic Service"
    }
}

resource "aws_route_table_association" "public_kube" {
    subnet_id = "${aws_subnet.public_kube.id}"
    route_table_id = "${aws_route_table.public.id}"
}

resource "aws_subnet" "public_kube" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "172.${var.vpc_octet}.129.0/24"
    map_public_ip_on_launch = true
    availability_zone = "${data.aws_availability_zones.available.names[0]}"
    tags = "${map("Name", "public_kube", "Organization", "Basic Service", "Environment", var.vpc_name, "kubernetes.io/cluster/${var.vpc_name}", "shared", "kubernetes.io/role/elb", "")}"
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
        Organization = "Basic Service"
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
        Organization = "Basic Service"
    }
    vpc_security_group_ids = ["${aws_security_group.local.id}"]
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
        Organization = "Basic Service"
    }
}

data "aws_acm_certificate" "api" {
  domain   = "${var.aws_cert_name}"
  statuses = ["ISSUED"]
}

data "template_file" "cluster" {
    template = "${file("${path.module}/../configs/cluster.yaml")}"
    vars {
        cluster_name = "${var.vpc_name}"
        key_name = "${aws_key_pair.automation_dev.key_name}"
        aws_region = "${var.aws_region}"
        kms_key = "${aws_kms_key.kube_key.arn}"
        route_table_id = "${aws_route_table.private_kube.id}"
        vpc_id ="${aws_vpc.main.id}"
        vpc_cidr = "${aws_vpc.main.cidr_block}"
        subnet_id = "${aws_subnet.private_kube.id}"
        subnet_cidr = "${aws_subnet.private_kube.cidr_block}"
        subnet_zone = "${aws_subnet.private_kube.availability_zone}"
        security_group_id = "${aws_security_group.kube-worker.id}"
        kube_additional_keys = "${var.kube_additional_keys}"
        hosted_zone = "${aws_route53_zone.main.id}"
    }
}

data "template_file" "creds" {
    template = "${file("${path.module}/../configs/creds.tpl")}"
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
        gdcapi_secret_key = "${var.gdcapi_secret_key}"
        gdcapi_indexd_password = "${var.gdcapi_indexd_password}"
    }
}

data "template_file" "kube_up" {
    template = "${file("${path.module}/../configs/kube-up.sh")}"
    vars {
        vpc_name = "${var.vpc_name}"
        s3_bucket = "${var.kube_bucket}"
    }
}

data "template_file" "configmap" {
    template = "${file("${path.module}/../configs/00configmap.yaml")}"
    vars {
        vpc_name = "${var.vpc_name}"
        hostname = "${var.hostname}"
        revproxy_arn = "${data.aws_acm_certificate.api.arn}"
    }
}

data "template_file" "kube_services" {
    template = "${file("${path.module}/../configs/kube-services.sh")}"
    vars {
        vpc_name = "${var.vpc_name}"
        s3_bucket = "${var.kube_bucket}"
    }
}

data "template_file" "aws_creds" {
    template = "${file("${path.module}/../configs/aws_credentials")}"
    vars {
        access_key = "${var.aws_access_key}"
        secret_key = "${var.aws_secret_key}"
    }
}
resource "aws_instance" "kube_provisioner" {
    ami = "${var.login_ami}"
    subnet_id = "${aws_subnet.private_kube.id}"
    instance_type = "t2.micro"
    monitoring = true
    vpc_security_group_ids = ["${aws_security_group.local.id}"]
    tags {
        Name = "Kube Provisioner"
        Environment = "${var.vpc_name}"
        Organization = "Basic Service"
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
        command = "echo \"${data.template_file.configmap.rendered}\" > ${var.vpc_name}_output/00configmap.yaml"
    }
    provisioner "local-exec" {
        command = "echo \"${data.template_file.aws_creds.rendered}\" > ${var.vpc_name}_output/credentials"
    }
    provisioner "local-exec" {
        command = "cp ${path.module}/../configs/render_creds.py ${var.vpc_name}_output/"
    }
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
        Organization = "Basic Service"
    }
}

resource "aws_key_pair" "automation_dev" {
    key_name = "${var.vpc_name}_automation_dev"
    public_key = "${var.kube_ssh_key}"
}

resource "aws_s3_bucket" "kube_bucket" {
  bucket = "${var.kube_bucket}"
  acl    = "private"

  tags {
    Name        = "${var.kube_bucket}"
    Environment = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}
