#
# Trying to move toward a model where terraform
# outputs all variables necessary for subsequent
# post-terraform devops.
# We then work like this:
#    terraform output -json > "${vpcname}.json"
# , and subsequent automation scripts consume ${vpcname}.json
# as an input.
#

output "aws_region" {
  value = "${var.aws_region}"
}

output "vpc_name" {
  value = "${var.vpc_name}"
}

output "vpc_cidr_block" {
  value = "${module.cdis_vpc.vpc_cidr_block}"
}

output "indexd_rds_id" {
  value = "${aws_db_instance.db_indexd.*.id}"
}

output "fence_rds_id" {
  value = "${aws_db_instance.db_fence.*.id}"
}

output "gdcapi_rds_id" {
  value = "${aws_db_instance.db_gdcapi.*.id}"
}

output "fence-bot_user_secret" {
  value = "${module.cdis_vpc.fence-bot_secret}"
#  value = "${module.fence-bot-user.fence-bot_secret}"
}

output "fence-bot_user_id" {
#  value = "${module.fence-bot-user.fence-bot_id}"
  value = "${module.cdis_vpc.fence-bot_id}"
}

output "data-bucket_name" {
  value = "${module.cdis_vpc.data-bucket_name}"
}


#--------------------------------------------------------------
# Legacy stuff ...
# We want to move away from generating output files, and
# instead just publish output variables
#
#resource "null_resource" "config_setup" {
#  provisioner "local-exec" {
#    command = "echo \"${module.config_files.k8s_vars_sh}\" | cat - \"${path.module}/kube-up-body.sh\" > ${var.vpc_name}_output/kube-up.sh"
#  }
#}
