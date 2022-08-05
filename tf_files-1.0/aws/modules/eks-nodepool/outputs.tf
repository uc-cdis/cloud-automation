output "nodepool_role" {
  value = aws_iam_role.eks_node_role.arn
}

output "nodepool_sg" {
  value = aws_security_group.eks_nodes_sg.id
}
