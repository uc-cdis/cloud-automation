
output "athena_region" {
  value = data.aws_region.current.name
}

output "athena_database_name" {
  value = aws_glue_catalog_database.cur-glue-database.name
}

output "athena_table_name" {
  value = aws_glue_catalog_table.cur-glue-catalog.name
}

output "athena_result_bucket" {
  value = "s3://aws-athena-query-results-${data.aws_caller_identity.current.account_id}-${data.aws_region_current.name}/"
}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "kubectcost-user-id" {
  value = "${aws_iam_access_key.kubecost-user-key.id}"
}

output "kubecost-user-secret" {
  value = "${aws_iam_access_key.kubecost-user-key.secret}"
}