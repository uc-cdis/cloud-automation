output "k8s_configmap" {
  value = "${data.template_file.configmap.rendered}"
}

output "k8s_service_creds" {
  value = "${data.template_file.creds.rendered}"
}

#output "k8s_vars_sh" {
#  value = "${data.template_file.kube_vars.rendered}"
#}
