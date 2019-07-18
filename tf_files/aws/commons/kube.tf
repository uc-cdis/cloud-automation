resource "aws_security_group" "kube-worker" {
  name                        = "kube-worker"
  description                 = "security group that open ports to vpc, this needs to be attached to kube worker"
  vpc_id                      = "${module.cdis_vpc.vpc_id}"

  ingress {
    from_port                 = 30000
    to_port                   = 30100
    protocol                  = "TCP"
    #cidr_blocks = ["172.${var.vpc_octet2}.${var.vpc_octet3}.0/20", "${var.csoc_cidr}"]
    #cidr_blocks = ["${var.vpc_cidr_block}","${var.csoc_cidr}"]
    #cidr_blocks               = ["${var.vpc_cidr_block}","${var.csoc_managed == "yes" ? var.peering_cidr : ""}"]
    cidr_blocks               = ["${var.vpc_cidr_block}","${var.peering_cidr}"]
  }

  ingress {
    from_port                 = 443
    to_port                   = 443
    protocol                  = "TCP"
    #cidr_blocks               = ["${var.csoc_cidr}"]
    #cidr_blocks               = ["${var.csoc_managed == "yes" ? var.peering_cidr : data.aws_vpc.csoc_vpc.cidr_block}"]
    cidr_blocks               = ["${var.peering_cidr}"]
  }

  tags {
    Environment               = "${var.vpc_name}"
    Organization              = "${var.organization_name}"
  }
}

#
# Only create db_fence if var.db_password_fence is set.
# Sort of a hack during userapi to fence switch over.
#
resource "aws_db_instance" "db_fence" {
  allocated_storage           = "${var.db_size}"
  identifier                  = "${var.vpc_name}-fencedb"
  storage_type                = "gp2"
  engine                      = "postgres"
  engine_version              = "9.6.11"
  parameter_group_name        = "${aws_db_parameter_group.rds-cdis-pg.name}"
  instance_class              = "${var.db_instance}"
  name                        = "fence"
  username                    = "fence_user"
  password                    = "${var.db_password_fence}"
  snapshot_identifier         = "${var.fence_snapshot}"
  db_subnet_group_name        = "${aws_db_subnet_group.private_group.id}"
  vpc_security_group_ids      = ["${module.cdis_vpc.security_group_local_id}"]
  allow_major_version_upgrade = true
  final_snapshot_identifier   = "${replace(var.vpc_name,"_", "-")}-fencedb"
  maintenance_window          = "SAT:09:00-SAT:09:59"
  backup_retention_period     = "4"
  backup_window               = "06:00-06:59"
  multi_az                    = "${var.fence_ha}" 

  tags {
    Environment               = "${var.vpc_name}"
    Organization              = "${var.organization_name}"
  } 

  lifecycle {
    prevent_destroy = true
    #ignore_changes  = ["*"]
    ignore_changes = ["engine_version"]
  }
}

resource "aws_db_instance" "db_gdcapi" {
  allocated_storage           = "${var.db_size}"
  identifier                  = "${var.vpc_name}-gdcapidb"
  storage_type                = "gp2"
  engine                      = "postgres"
  engine_version              = "9.6.11"
  parameter_group_name        = "${aws_db_parameter_group.rds-cdis-pg.name}"
  instance_class              = "${var.db_instance}"
  name                        = "gdcapi"
  username                    = "sheepdog"
  password                    = "${var.db_password_sheepdog}"
  snapshot_identifier         = "${var.gdcapi_snapshot}"
  db_subnet_group_name        = "${aws_db_subnet_group.private_group.id}"
  vpc_security_group_ids      = ["${module.cdis_vpc.security_group_local_id}"]
  allow_major_version_upgrade = true
  final_snapshot_identifier   = "${replace(var.vpc_name,"_", "-")}-gdcapidb"
  maintenance_window          = "SAT:10:00-SAT:10:59"
  backup_retention_period     = "4"
  backup_window               = "07:00-07:59"
  multi_az                    = "${var.sheepdog_ha}" 

  tags {
    Environment               = "${var.vpc_name}"
    Organization              = "${var.organization_name}"
  }

  lifecycle {
    prevent_destroy = true
    #ignore_changes  = ["*"]
    ignore_changes = ["engine_version"]
  }
}

resource "aws_db_instance" "db_indexd" {
  allocated_storage           = "${var.db_size}"
  identifier                  = "${var.vpc_name}-indexddb"
  storage_type                = "gp2"
  engine                      = "postgres"
  engine_version              = "9.6.11"
  parameter_group_name        = "${aws_db_parameter_group.rds-cdis-pg.name}"
  instance_class              = "${var.db_instance}"
  name                        = "indexd"
  username                    = "indexd_user"
  password                    = "${var.db_password_indexd}"
  snapshot_identifier         = "${var.indexd_snapshot}"
  db_subnet_group_name        = "${aws_db_subnet_group.private_group.id}"
  vpc_security_group_ids      = ["${module.cdis_vpc.security_group_local_id}"]
  allow_major_version_upgrade = true
  final_snapshot_identifier   = "${replace(var.vpc_name,"_", "-")}-indexddb"
  maintenance_window          = "SAT:11:00-SAT:11:59"
  backup_retention_period     = "4"
  backup_window               = "08:00-08:59"
  multi_az                    = "${var.indexd_ha}" 

  tags {
    Environment               = "${var.vpc_name}"
    Organization              = "${var.organization_name}"
  }

  lifecycle {
    prevent_destroy = true
    #ignore_changes  = ["*"]
    ignore_changes = ["engine_version"]
  }
}

# See https://www.postgresql.org/docs/9.6/static/runtime-config-logging.html
# and https://www.postgresql.org/docs/9.6/static/runtime-config-query.html#RUNTIME-CONFIG-QUERY-ENABLE
# for detail parameter descriptions

resource "aws_db_parameter_group" "rds-cdis-pg" {
  name   = "${var.vpc_name}-rds-cdis-pg"
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

  lifecycle {
    ignore_changes  = ["*"]
  }
}

resource "aws_kms_key" "kube_key" {
  description                 = "encryption/decryption key for kubernete"
  enable_key_rotation         = true

  tags {
    Environment               = "${var.vpc_name}"
    Organization              = "${var.organization_name}"
  }
}

resource "aws_kms_alias" "kube_key" {
  name                        = "alias/${var.vpc_name}-k8s"
  target_key_id               = "${aws_kms_key.kube_key.key_id}"
}

resource "aws_key_pair" "automation_dev" {
  key_name                    = "${var.vpc_name}_automation_dev"
  public_key                  = "${var.kube_ssh_key}"
}

resource "aws_s3_bucket" "kube_bucket" {
  # S3 buckets are in a global namespace, so dns style naming
  bucket                      = "kube-${replace(var.vpc_name,"_", "-")}-gen3"
  acl                         = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags {
    Name                      = "kube-${replace(var.vpc_name,"_", "-")}-gen3"
    Environment               = "${var.vpc_name}"
    Organization              = "${var.organization_name}"
  }

  lifecycle {
    # allow same bucket between stacks
    ignore_changes = ["tags", "bucket"]
  }
}


resource "aws_s3_bucket_public_access_block" "kube_bucket_privacy" {
  bucket                      = "${aws_s3_bucket.kube_bucket.id}"

  block_public_acls           = true
  block_public_policy         = true
  ignore_public_acls          = true
  restrict_public_buckets     = true
}


# user.yaml bucket read policy
# This bucket is in the 'bionimbus' account -
#   modify the permissions there as necessary.  Ugh.
data "aws_iam_policy_document" "configbucket_reader" {
  statement {
    actions = [
      "s3:Get*",
      "s3:List*",
    ]

    effect    = "Allow"
    resources = ["arn:aws:s3:::cdis-gen3-users", "arn:aws:s3:::cdis-gen3-users/${var.config_folder}/*"]
  }
}

resource "aws_iam_policy" "configbucket_reader" {
  name                        = "bucket_reader_cdis-gen3-users_${var.vpc_name}"
  description                 = "Read cdis-gen3-users/${var.config_folder}"
  policy                      = "${data.aws_iam_policy_document.configbucket_reader.json}"
}
