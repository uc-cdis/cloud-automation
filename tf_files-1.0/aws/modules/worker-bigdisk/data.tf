data "aws_instance" "worker" {
  filter {
    name   = "network-interface.addresses.private-ip-address"
    values = [var.instance_ip]
  }
}
