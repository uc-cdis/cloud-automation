output "squid_public_ip" {
  value = "${aws_instance.proxy.*.public_ip}"
}

output "squid_private_ip" {
  value = "${aws_instance.proxy.*.private_ip}"
}

output "squid_id" {
  value = "${aws_instance.proxy.*.id}"
}
