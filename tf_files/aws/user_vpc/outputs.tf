output "aws_region" {
  value = "${var.aws_region}"
}

output "login_ip" {
  value = "${aws_eip.login.public_ip}"
}

output "vpc_name" {
  value = "${var.vpc_name}"
}

output "vpc_cidr_block" {
  value = "${module.cdis_vpc.vpc_cidr_block}"
}

output "ssh_config" {
  value = "${data.template_file.ssh_config.rendered}"
}

#-------------------------------------------

data "template_file" "ssh_config" {
  template = "${file("${path.module}/ssh_config.tpl")}"

  vars {
    vpc_name        = "${var.vpc_name}"
    login_public_ip = "${aws_eip.login.public_ip}"
  }
}
