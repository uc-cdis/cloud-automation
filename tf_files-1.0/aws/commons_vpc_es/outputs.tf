

output "kibana_endpoint" {
  value = "${module.commons_vpc_es.kibana_endpoint}"
}

output "es_endpoint" {
  value = "${module.commons_vpc_es.es_endpoint}"
}
