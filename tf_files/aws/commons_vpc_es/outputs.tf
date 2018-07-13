

output "kibana_endpoint" {
  value = "${module.commons_vpc_es.kibana_endpoint}"
}

output "es_user_key" {
  value = "${module.commons_vpc_es.es_user_key}"
}

output "es_endpoint" {
  value = "${module.commons_vpc_es.es_endpoint}"
}

output "es_user_key_id" {
  value = "${module.commons_vpc_es.es_user_key_id}"
}

