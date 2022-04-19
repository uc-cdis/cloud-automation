
output "kibana_endpoint" {
  value = "${aws_elasticsearch_domain.gen3_metadata.kibana_endpoint}"
}

output "es_endpoint" {
  value = "${aws_elasticsearch_domain.gen3_metadata.endpoint}"
}

