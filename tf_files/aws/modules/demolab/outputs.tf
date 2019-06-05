
output "vpc_id" {
  value = "${module.vpc.vpc_id}"
}

output "iplist" {
  value = ["${aws_eip.ips.*.public_ip}"]
}
