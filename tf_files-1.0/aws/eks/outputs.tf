output "kubeconfig" {
  value = module.eks[0].kubeconfig
}

output "config_map_aws_auth" {
  value = module.eks[0].config_map_aws_auth
}
