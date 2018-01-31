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

output "login_ip" {
  value = "${module.cdis_vpc.login_ip}"
}

output "vpc_name" {
  value = "${var.vpc_name}"
}

output "k8s_cluster" {
  value = "${data.template_file.cluster.rendered}"
}

output "k8s_configmap" {
  value = "${data.template_file.configmap.rendered}"
}

output "service_creds" {
  value = "${data.template_file.creds.rendered}"
}

output "ssh_config" {
  value = "${data.template_file.ssh_config.rendered}"
}

output "indexd_rds_id" {
  value = "${aws_db_instance.db_indexd.id}"
}

output "fence_rds_id" {
  value = "${join(" ", coalescelist(aws_db_instance.db_userapi.*.id, aws_db_instance.db_fence.*.id))}"
}

output "gdcapi_rds_id" {
  value = "${aws_db_instance.db_gdcapi.id}"
}

#-----------------------------

data "template_file" "cluster" {
    template = "${file("${path.module}/../configs/cluster.yaml")}"
    vars {
        cluster_name = "${var.vpc_name}"
        key_name = "${aws_key_pair.automation_dev.key_name}"
        aws_region = "${var.aws_region}"
        kms_key = "${aws_kms_key.kube_key.arn}"
        route_table_id = "${aws_route_table.private_kube.id}"
        vpc_id ="${module.cdis_vpc.vpc_id}"
        vpc_cidr = "${module.cdis_vpc.vpc_cidr_block}"
        subnet_id = "${aws_subnet.private_kube.id}"
        subnet_cidr = "${aws_subnet.private_kube.cidr_block}"
        subnet_zone = "${aws_subnet.private_kube.availability_zone}"
        security_group_id = "${aws_security_group.kube-worker.id}"
        kube_additional_keys = "${var.kube_additional_keys}"
        hosted_zone = "${module.cdis_vpc.zone_id}"
    }
}

#
# Note - we normally either have a userapi or a fence database - not both.
# Once userapi is completely retired, then we can get rid of these userapi vs fence checks.
#
# Note: using coalescelist/splat trick described here:
#      https://github.com/coreos/tectonic-installer/blob/master/modules/aws/vpc/vpc.tf
#      https://github.com/hashicorp/terraform/issues/11566
#
data "template_file" "creds" {
    template = "${file("${path.module}/../configs/creds.tpl")}"
    vars {
        fence_host = "${join(" ", coalescelist(aws_db_instance.db_fence.*.address, aws_db_instance.db_userapi.*.address))}"
        fence_user = "${var.db_password_fence != "" ? "fence_user" : "userapi_user"}"
        fence_pwd = "${var.db_password_fence != "" ? var.db_password_fence : var.db_password_userapi}"
        fence_db = "${join(" ", coalescelist(aws_db_instance.db_fence.*.name, aws_db_instance.db_userapi.*.name))}"
        userapi_host = "${join(" ", coalescelist(aws_db_instance.db_userapi.*.address, aws_db_instance.db_fence.*.address))}"
        userapi_user = "${var.db_password_userapi != "" ? "userapi_user" : "fence_user"}"
        userapi_pwd = "${var.db_password_userapi != "" ? var.db_password_userapi : var.db_password_fence}"
        userapi_db = "${join(" ", coalescelist(aws_db_instance.db_userapi.*.name, aws_db_instance.db_fence.*.name))}"
        gdcapi_host = "${aws_db_instance.db_gdcapi.address}"
        gdcapi_user = "${aws_db_instance.db_gdcapi.username}"
        gdcapi_pwd = "${aws_db_instance.db_gdcapi.password}"
        gdcapi_db = "${aws_db_instance.db_gdcapi.name}"
        peregrine_user = "peregrine"
        peregrine_pwd = "${var.db_password_peregrine}"
        sheepdog_user = "sheepdog"
        sheepdog_pwd = "${var.db_password_sheepdog}"
        indexd_host = "${aws_db_instance.db_indexd.address}"
        indexd_user = "${aws_db_instance.db_indexd.username}"
        indexd_pwd = "${aws_db_instance.db_indexd.password}"
        indexd_db = "${aws_db_instance.db_indexd.name}"
        hostname = "${var.hostname}"
        google_client_secret = "${var.google_client_secret}"
        google_client_id = "${var.google_client_id}"
        hmac_encryption_key = "${var.hmac_encryption_key}"
        gdcapi_secret_key = "${var.gdcapi_secret_key}"
        gdcapi_indexd_password = "${var.gdcapi_indexd_password}"
        gdcapi_oauth2_client_id = "${var.gdcapi_oauth2_client_id}"
        gdcapi_oauth2_client_secret = "${var.gdcapi_oauth2_client_secret}"
    }
}

data "template_file" "kube_vars" {
    template = "${file("${path.module}/../configs/kube-vars.sh.tpl")}"
    vars {
        vpc_name = "${var.vpc_name}"
        s3_bucket = "${var.kube_bucket}"
        fence_snapshot = "${var.fence_snapshot}"
        gdcapi_snapshot = "${var.gdcapi_snapshot}"
    }
}

data "template_file" "ssh_config" {
    template = "${file("${path.module}/../configs/ssh_config.tpl")}"
    vars {
        vpc_name = "${var.vpc_name}"
        login_public_ip = "${module.cdis_vpc.login_ip}"
        k8s_ip = "${aws_instance.kube_provisioner.private_ip}"
    }
}

data "template_file" "configmap" {
    template = "${file("${path.module}/../configs/00configmap.yaml")}"
    vars {
        vpc_name = "${var.vpc_name}"
        hostname = "${var.hostname}"
        revproxy_arn = "${data.aws_acm_certificate.api.arn}"
        dictionary_url = "${var.dictionary_url}"
    }
}



#--------------------------------------------------------------
# Legacy stuff ...
# We want to move away from generating output files, and
# instead just publish output variables
#
resource "null_resource" "config_setup" {
    triggers {
      creds_change = "${data.template_file.creds.rendered}"
      vars_change = "${data.template_file.kube_vars.rendered}"
      config_change = "${data.template_file.configmap.rendered}"
      cluster_change = "${data.template_file.cluster.rendered}"
    }

    provisioner "local-exec" {
        command = "mkdir ${var.vpc_name}_output; echo '${data.template_file.creds.rendered}' >${var.vpc_name}_output/creds.json"
    }

    provisioner "local-exec" {
        command = "echo \"${data.template_file.cluster.rendered}\" > ${var.vpc_name}_output/cluster.yaml"
    }
    provisioner "local-exec" {
        command = "echo \"${data.template_file.kube_vars.rendered}\" | cat - \"${path.module}/../configs/kube-up-body.sh\" > ${var.vpc_name}_output/kube-up.sh"
    }

    provisioner "local-exec" {
        command = "echo \"${data.template_file.kube_vars.rendered}\" | cat - \"${path.module}/../configs/kube-setup-certs.sh\" \"${path.module}/../configs/kube-services-body.sh\" \"${path.module}/../configs/kube-setup-fence.sh\" \"${path.module}/../configs/kube-setup-sheepdog.sh\" \"${path.module}/../configs/kube-setup-peregrine.sh\" > ${var.vpc_name}_output/kube-services.sh"
    }

    provisioner "local-exec" {
        command = "echo \"${data.template_file.configmap.rendered}\" > ${var.vpc_name}_output/00configmap.yaml"
    }
    provisioner "local-exec" {
        command = "cp ${path.module}/../configs/render_creds.py ${var.vpc_name}_output/"
    }
}

