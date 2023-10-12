module "commons_vpc_es" {
  source                  = "../modules/commons-vpc-es"
  count                   = var.deploy_es ? 1 : 0
  vpc_name                = var.vpc_name
  vpc_id                  = module.cdis_vpc.vpc_id
  instance_type           = var.es_instance_type
  ebs_volume_size_gb      = var.ebs_volume_size_gb
  encryption              = var.encryption
  instance_count          = var.es_instance_count
  organization_name       = var.organization_name
  es_version              = var.es_version
  es_linked_role          = var.es_linked_role
  depends_on              = [module.cdis_vpc.vpc_id, module.cdis_vpc.vpc_peering_id]
}

