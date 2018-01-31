output "login_ip" {
  value = "${aws_eip.login.public_ip}"
}

output "login_ami_id" {
  value = "${aws_ami_copy.login_ami.id}"
}

output "proxy_id" {
  value = "${aws_instance.proxy.id}"
}

output "zone_zid" {
  value = "${aws_route53_zone.main.zone_id}"
}

output "zone_id" {
  value = "${aws_route53_zone.main.id}"
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

output "security_group_local_id" {
  value = "${aws_security_group.local.id}"
}


output "ssh_config" {
  value = "${data.template_file.ssh_config.rendered}"
}

#-------------------------------------------

data "template_file" "ssh_config" {
    template = "${file("${path.module}/ssh_config.tpl")}"
    vars {
        vpc_name = "${var.vpc_name}"
        login_public_ip = "${aws_eip.login.public_ip}"
    }
}
