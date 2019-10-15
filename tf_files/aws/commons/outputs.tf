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

#output "k8s_cluster" {
#  value = "${data.template_file.cluster.rendered}"
#}

#output "k8s_configmap" {
#  value = "${module.config_files.k8s_configmap}"
#}

#output "service_creds" {
#  value = "${module.config_files.k8s_service_creds}"
#}

output "indexd_rds_id" {
  value = "${aws_db_instance.db_indexd.id}"
}

output "fence_rds_id" {
  value = "${aws_db_instance.db_fence.id}"
}

output "gdcapi_rds_id" {
  value = "${aws_db_instance.db_gdcapi.id}"
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


#-----------------------------

data "template_file" "cluster" {
  template = "${file("${path.module}/cluster.yaml")}"

  vars {
    cluster_name         = "${local.cluster_name}"
    key_name             = "${aws_key_pair.automation_dev.key_name}"
    aws_region           = "${var.aws_region}"
    kms_key              = "${aws_kms_key.kube_key.arn}"
    route_table_id       = "${aws_route_table.private_kube.id}"
    vpc_id               = "${module.cdis_vpc.vpc_id}"
    vpc_cidr             = "${module.cdis_vpc.vpc_cidr_block}"
    subnet_id            = "${aws_subnet.private_kube.id}"
    subnet_cidr          = "${aws_subnet.private_kube.cidr_block}"
    subnet_zone          = "${aws_subnet.private_kube.availability_zone}"
#    security_group_id    = "${aws_security_group.kube-worker.id}"
    kube_additional_keys = "${var.kube_additional_keys}"
    hosted_zone          = "${module.cdis_vpc.zone_id}"
    s3_bucket            = "${aws_s3_bucket.kube_bucket.id}"
    log_bucket_policy    = "${module.elb_logs.rw_policy_arn}"
    config_bucket_policy = "${aws_iam_policy.configbucket_reader.arn}"
  }
}

#--------------------------------------------------------------
# Legacy stuff ...
# We want to move away from generating output files, and
# instead just publish output variables
#
resource "null_resource" "config_setup" {
#  triggers {
#    cluster_change = "${data.template_file.cluster.rendered}"
#  }

#  provisioner "local-exec" {
#    command = "mkdir ${var.vpc_name}_output; echo '${data.template_file.cluster.rendered}' > ${var.vpc_name}_output/kube-aws.cluster.yaml"
#  }

  provisioner "local-exec" {
    command = "echo \"${module.config_files.k8s_vars_sh}\" | cat - \"${path.module}/kube-up-body.sh\" > ${var.vpc_name}_output/kube-up.sh"
  }
}
