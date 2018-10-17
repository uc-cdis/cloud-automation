output "qualys_public_ip" {
 value = "${module.qualys_vm.qualys_public_ip}"
}


output "qualys_private_ip" {
 value = "${module.qualys_vm.qualys_private_ip}"
}
