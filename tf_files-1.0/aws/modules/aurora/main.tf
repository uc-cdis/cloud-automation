#########################
# Create Master password
#########################

resource "random_password" "password" {
  length  = var.password_length
  special = false
}

#############
# RDS Aurora
#############

# Aurora Cluster

resource "aws_rds_cluster" "postgresql" {
  cluster_identifier        = "${var.vpc_name}-${var.cluster_identifier}"
  engine                    = var.cluster_engine
  engine_version	          = var.cluster_engine_version
  db_subnet_group_name	    = "${var.vpc_name}_private_group"
  vpc_security_group_ids    = [data.aws_security_group.private.id]
  master_username           = var.master_username
  master_password	          = random_password.password.result
  storage_encrypted	        = var.storage_encrypted
  apply_immediately         = var.apply_immediate
  engine_mode        	      = var.engine_mode
  skip_final_snapshot	      = var.skip_final_snapshot
  final_snapshot_identifier = var.final_snapshot_identifier
  backup_retention_period   = var.backup_retention_period
  preferred_backup_window   = var.preferred_backup_window

  serverlessv2_scaling_configuration {
    max_capacity = var.serverlessv2_scaling_max_capacity
    min_capacity = var.serverlessv2_scaling_min_capacity
  }
}

# Aurora Cluster Instance

resource "aws_rds_cluster_instance" "postgresql" {
  db_subnet_group_name = aws_rds_cluster.postgresql.db_subnet_group_name
  identifier         	 = "${var.vpc_name}-${var.cluster_instance_identifier}"
  cluster_identifier 	 = aws_rds_cluster.postgresql.id
  instance_class	     = var.cluster_instance_class
  engine             	 = aws_rds_cluster.postgresql.engine
  engine_version     	 = aws_rds_cluster.postgresql.engine_version
}


#############################
# Aurora Creds to Local File
#############################

# Local variable to hold aurora creds
locals {
  aurora-creds-template     = <<AURORACREDS
{
    "aurora": {
        "db_host": "${aws_rds_cluster.postgresql.endpoint}",
        "db_username": "${aws_rds_cluster.postgresql.master_username}",
        "db_password": "${aws_rds_cluster.postgresql.master_password}",
    }
}
AURORACREDS
}

# generating aurora-creds.json
resource "local_sensitive_file" "aurora_creds" {
  content  = local.aurora-creds-template
  filename = "${path.cwd}/${var.vpc_name}_output/aurora-creds.json"
}
