output "kibana_endpoint" {
  value = module.commons_vpc_es[0].kibana_endpoint
}

output "es_endpoint" {
  value = module.commons_vpc_es[0].es_endpoint
}
