output "kubeconfig" {
  value =   templatefile("${path.module}/kubeconfig.tpl", {vpc_name = var.vpc_name, eks_name = aws_eks_cluster.eks_cluster.id, eks_endpoint = aws_eks_cluster.eks_cluster.endpoint, eks_cert = aws_eks_cluster.eks_cluster.certificate_authority.0.data,})
  sensitive = true
}

output "config_map_aws_auth" {
  value = local.config-map-aws-auth
  sensitive = true
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
  sensitive = true
}

output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.eks_cluster.certificate_authority.0.data
  sensitive = true
}
  
output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}
