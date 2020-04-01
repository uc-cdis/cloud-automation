




output "zone_zid" {
  value = "${aws_route53_zone.main.zone_id}"
}

output "zone_id" {
  value = "${aws_route53_zone.main.id}"
}

output "zone_name" {
  value = "${aws_route53_zone.main.name}"
}

output "vpc_id" {
  value = "${aws_vpc.main.id}"
}

output "vpc_cidr_block" {
  value = "${aws_vpc.main.cidr_block}"
}

output "public_route_table_id" {
  value = "${aws_route_table.public.id}"
}

output "gateway_id" {
  value = "${aws_internet_gateway.gw.id}"
}


output "public_subnet_id" {
  value = "${aws_subnet.public.id}"
}


output "security_group_local_id" {
  value = "${aws_security_group.local.id}"
}

output "nat_gw_id" {
  value = "${aws_nat_gateway.nat_gw.id}"
}

output "ssh_key_name" {
  value = "${var.ssh_key_name}"
}

output "vpc_peering_id" {
  value = "${aws_vpc_peering_connection.vpcpeering.id}"
}

output "es_user_key" {
  value = "${aws_iam_access_key.es_user_key.secret}"
}

output "es_user_key_id" {
  value = "${aws_iam_access_key.es_user_key.id}"
}

output "cwlogs" {
  value = "${aws_cloudwatch_log_group.main_log_group.arn}"
}

output "fence-bot_id" {
  value = "${module.fence-bot-user.fence-bot_id}"
}

output "fence-bot_secret" {
  value = "${module.fence-bot-user.fence-bot_secret}"
}

output "data-bucket_name" {
  value = "${module.data-bucket.data-bucket_name}"
}
