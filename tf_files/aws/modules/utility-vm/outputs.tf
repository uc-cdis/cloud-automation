output "utility_private_ip" {
 value = "${aws_instance.utility_vm.private_ip}"
}

output "role_id" {
  value = "${aws_iam_role.vm_role.name}"
}


