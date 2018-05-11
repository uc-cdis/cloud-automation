output "admin_private_ip" {
 value = "${aws_instance.login.private_ip}"
}

output "role_id" {
  value = "${aws_iam_role.child_role.name}"
}


