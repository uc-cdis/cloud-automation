module "aurora" {
  source				                    = "../modules/aurora"
  count					                    = var.deploy_aurora ? 1 : 0
  vpc_name				                  = var.vpc_name
  cluster_identifier			          = var.cluster_identifier
  cluster_instance_identifier		    = var.cluster_instance_identifier
  cluster_instance_class		        = var.cluster_instance_class
  cluster_engine			              = var.cluster_engine
  cluster_engine_version		        = var.cluster_engine_version
  master_username			              = var.master_username
  storage_encrypted			            = var.storage_encrypted
  apply_immediate			              = var.apply_immediate
  engine_mode				                = var.engine_mode
  serverlessv2_scaling_min_capacity	= var.serverlessv2_scaling_min_capacity
  serverlessv2_scaling_max_capacity	= var.serverlessv2_scaling_max_capacity
  skip_final_snapshot			          = var.skip_final_snapshot
  final_snapshot_identifier		      = var.final_snapshot_identifier
  backup_retention_period		        = var.backup_retention_period
  preferred_backup_window		        = var.preferred_backup_window
  password_length			              = var.password_length
  secrets_manager_enabled           = var.secrets_manager_enabled
  depends_on                        = [module.cdis_vpc.vpc_id, module.cdis_vpc.vpc_peering_id]
}
