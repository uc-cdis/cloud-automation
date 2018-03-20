


output "squid_public_ip" {
  value = "${aws_instance.proxy.public_ip}"
}