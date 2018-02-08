output "aws_region" {
  value = "${var.aws_region}"
}

output "login_ip" {
  value = "${module.cdis_vpc.login_ip}"
}

output "vpc_name" {
  value = "${var.vpc_name}"
}

output "vpc_cidr_block" {
  value = "${module.cdis_vpc.vpc_cidr_block}"
}

output "ssh_config" {
  value = "${module.cdis_vpc.ssh_config}"
}
