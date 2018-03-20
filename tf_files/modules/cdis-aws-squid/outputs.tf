output "squid_private_ip" {
  value = "${aws_instance.proxy.private_ip}"
}
