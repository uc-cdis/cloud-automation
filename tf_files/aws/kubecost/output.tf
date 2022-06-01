
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
  value = "s3://aws-athena-query-results-${local.account_id}-${local.region}/"
}

output "aws_account_id" {
  value = local.account_id
}
