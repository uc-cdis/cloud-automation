
output "kubeconfig" {
  value = "${data.template_file.kube_config.rendered}"
}

output "config_map_aws_auth" {
  value = "${local.config-map-aws-auth}"
}

