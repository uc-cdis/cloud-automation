
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

#
# Only create db_fence if var.db_password_fence is set.
# Sort of a hack during userapi to fence switch over.
#
resource "aws_db_instance" "db_fence" {
    count = "${var.db_password_fence != "" ? 1 : 0}"
    allocated_storage    = "${var.db_size}"
    identifier           = "${var.vpc_name}-fencedb"
    storage_type         = "gp2"
    engine               = "postgres"
    skip_final_snapshot  = true
    engine_version       = "9.6.5"
    parameter_group_name = "${aws_db_parameter_group.rds-cdis-pg.name}"
    instance_class       = "${var.db_instance}"
    name                 = "fence"
    username             = "fence_user"
    password             = "${var.db_password_fence}"
    snapshot_identifier  = "${var.fence_snapshot}"
    db_subnet_group_name = "${aws_db_subnet_group.private_group.id}"
    vpc_security_group_ids = ["${aws_security_group.local.id}"]
    tags {
        Environment = "${var.vpc_name}"
        Organization = "Basic Service"
    }
    lifecycle {
        ignore_changes = ["identifier", "name", "engine_version"]
    }
}

#
# Only create db_userapi if var.db_password_userapi is set
# Sort of a hack during userapi to fence switch over.
#
resource "aws_db_instance" "db_userapi" {
    count = "${var.db_password_userapi != "" ? 1 : 0}"
    allocated_storage    = "${var.db_size}"
    identifier           = "${var.vpc_name}-userapidb"
    storage_type         = "gp2"
    engine               = "postgres"
    skip_final_snapshot  = true
    engine_version       = "9.6.5"
    parameter_group_name = "${aws_db_parameter_group.rds-cdis-pg.name}"
    instance_class       = "${var.db_instance}"
    name                 = "userapi"
    username             = "userapi_user"
    password             = "${var.db_password_userapi}"
    db_subnet_group_name = "${aws_db_subnet_group.private_group.id}"
    vpc_security_group_ids = ["${aws_security_group.local.id}"]
    tags {
        Environment = "${var.vpc_name}"
        Organization = "Basic Service"
    }
    lifecycle {
        ignore_changes = ["identifier", "name", "engine_version", "snapshot_identifier"]
    }
}

resource "aws_db_instance" "db_gdcapi" {
    allocated_storage    = "${var.db_size}"
    identifier           = "${var.vpc_name}-gdcapidb"
    storage_type         = "gp2"
    engine               = "postgres"
    skip_final_snapshot  = true
    engine_version       = "9.6.5"
    parameter_group_name = "${aws_db_parameter_group.rds-cdis-pg.name}"
    instance_class       = "${var.db_instance}"
    name                 = "gdcapi"
    username             = "sheepdog"
    password             = "${var.db_password_sheepdog}"
    snapshot_identifier  = "${var.gdcapi_snapshot}"
    db_subnet_group_name = "${aws_db_subnet_group.private_group.id}"
    tags {
        Environment = "${var.vpc_name}"
        Organization = "Basic Service"
    }
    vpc_security_group_ids = ["${aws_security_group.local.id}"]
    lifecycle {
        ignore_changes = ["identifier", "name", "engine_version", "username", "password"]
    }
}

resource "aws_db_instance" "db_indexd" {
    allocated_storage    = "${var.db_size}"
    identifier           = "${var.vpc_name}-indexddb"
    storage_type         = "gp2"
    engine               = "postgres"
    skip_final_snapshot  = true
    engine_version       = "9.6.5"
    parameter_group_name = "${aws_db_parameter_group.rds-cdis-pg.name}"
    instance_class       = "${var.db_instance}"
    name                 = "indexd"
    username             = "indexd_user"
    password             = "${var.db_password_indexd}"
    snapshot_identifier  = "${var.indexd_snapshot}"
    db_subnet_group_name = "${aws_db_subnet_group.private_group.id}"
    vpc_security_group_ids = ["${aws_security_group.local.id}"]
    tags {
        Environment = "${var.vpc_name}"
        Organization = "Basic Service"
    }
    lifecycle {
        ignore_changes = ["identifier", "name", "engine_version"]
    }
}

# See https://www.postgresql.org/docs/9.6/static/runtime-config-logging.html
# and https://www.postgresql.org/docs/9.6/static/runtime-config-query.html#RUNTIME-CONFIG-QUERY-ENABLE
# for detail parameter descriptions

resource "aws_db_parameter_group" "rds-cdis-pg" {
  name   = "rds-cdis-pg"
  family = "postgres9.6"

# make index searches cheaper per row
  parameter {
    name  = "cpu_index_tuple_cost"
    value = "0.000005"
  }

# raise cost of search per row to be closer to read cost
# suggested for SSD backed disks
  parameter {
    name  = "cpu_tuple_cost"
    value = "0.7"
  }

# Log the duration of each SQL statement
  parameter {
    name  = "log_duration"
    value = "1"
  }
  
# Log statements above this duration
# 0 = everything
  parameter {
    name  = "log_min_duration_statement"
    value = "0"
  }

# lower cost of random reads from disk because we use SSDs
  parameter {
    name  = "random_page_cost"
    value = "0.7"
  }
}

data "aws_acm_certificate" "api" {
  domain   = "${var.aws_cert_name}"
  statuses = ["ISSUED"]
}

resource "aws_iam_role" "kube_provisioner" {
  name = "${var.vpc_name}_kube_provisioner"
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

resource "aws_iam_role_policy" "kube_provisioner" {
    name = "${var.vpc_name}_kube_provisioner"
    policy = "${data.aws_iam_policy_document.kube_provisioner.json}"
    role = "${aws_iam_role.kube_provisioner.id}"
}


resource "aws_iam_instance_profile" "kube_provisioner" {
  name  = "${var.vpc_name}_kube_provisioner"
  role = "${aws_iam_role.kube_provisioner.id}"
}

resource "aws_instance" "kube_provisioner" {
    ami = "${aws_ami_copy.login_ami.id}"
    subnet_id = "${aws_subnet.private_kube.id}"
    instance_type = "t2.micro"
    monitoring = true
    vpc_security_group_ids = ["${aws_security_group.local.id}"]
    iam_instance_profile = "${aws_iam_instance_profile.kube_provisioner.name}"
    tags {
        Name = "${var.vpc_name} Kube Provisioner"
        Environment = "${var.vpc_name}"
        Organization = "Basic Service"
    }
    lifecycle {
        ignore_changes = ["ami"]
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
    Organization = "Basic Service"
  }
  lifecycle {
    # allow same bucket between stacks
    ignore_changes = ["tags"]
  }
}
