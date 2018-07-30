
output "kubeconfig" {
  value = "${data.template_file.kube_config}"
}
