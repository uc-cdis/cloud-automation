


output "login_ami_id" {
  value = "${aws_ami_copy.login_ami.id}"
}

output "proxy_id" {
  value = "${module.squid_proxy.squid_id}"
}

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

output "logging_profile_name" {
  value = "${aws_iam_instance_profile.cluster_logging_cloudwatch.name}"
}

output "public_subnet_id" {
  value = "${aws_subnet.public.id}"
}

output "private_subnet_id" {
  value = "${aws_subnet.private_user.id}"
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
