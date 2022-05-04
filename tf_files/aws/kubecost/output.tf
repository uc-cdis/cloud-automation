output "kubecost-user-secret" {
  value = "${aws_iam_access_key.kubecost-user-key.secret}"
}

output "kubectcost-user-id" {
  value = "${aws_iam_access_key.kubecost-user-key.id}"
}
