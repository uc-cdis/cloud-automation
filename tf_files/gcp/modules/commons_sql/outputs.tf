output "indexd_db_ip" {
  value = "${google_sql_database_instance.indexd-master.ip_address.0.ip_address}"
}

output "fence_db_ip" {
  value = "${google_sql_database_instance.fence-master.ip_address.0.ip_address}"
}

output "sheepdog_db_ip" {
  value = "${google_sql_database_instance.sheepdog-master.ip_address.0.ip_address}"
}
