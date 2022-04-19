output "vpc_name" {
  value = "${var.vpc_name}"
}

output "indexd_snapshot_id" {
  value = "${aws_db_snapshot.indexd.db_instance_identifier}"
}

output "fence_snapshot_id" {
  value = "${aws_db_snapshot.fence.db_instance_identifier}"
}

output "sheepdog_snapshot_id" {
  value = "${aws_db_snapshot.sheepdog.db_instance_identifier}"
}
