
#output "kubeconfig" {
#  value = "${data.template_file.kube_config.rendered}"
#}

#output "config_map_aws_auth" {
#  value = "${local.config-map-aws-auth}"
#}

output "nodepool_role" {
  value = "${aws_iam_role.eks_node_role.arn}"
}

output "nodepool_sg" {
  value = "${aws_security_group.eks_nodes_sg.id}"
}
