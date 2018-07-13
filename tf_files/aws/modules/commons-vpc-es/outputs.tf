
output "kibana_endpoint" {
  value = "${aws_elasticsearch_domain.gen3_metadata.kibana_endpoint}"
}

output "es_endpoint" {
  value = "${aws_elasticsearch_domain.gen3_metadata.endpoint}"
}

output "es_user_key" {
  value = "${aws_iam_access_key.es_user_key.secret}"
}

output "es_user_key_id" {
  value = "${aws_iam_access_key.es_user_key.id}"
}
