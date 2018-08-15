output "qualys_public_ip" {
  value = "${aws_instance.qualys.public_ip}"
}

output "qualys_private_ip" {
  value = "${aws_instance.qualys.private_ip}"
}


