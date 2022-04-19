data "template_file" "creds" {
  template = file("${path.module}/creds.tpl")

  vars {
    fence_host                    = var.db_fence_address
    fence_user                    = var.db_fence_username
    fence_pwd                     = var.db_fence_password
    fence_db                      = var.db_fence_name
    sheepdog_host                 = var.db_sheepdog_address
    sheepdog_user                 = var.db_sheepdog_username
    sheepdog_pwd                  = var.db_sheepdog_password
    sheepdog_db                   = var.db_sheepdog_name
    peregrine_pwd                 = var.db_peregrine_password
    indexd_host                   = var.db_indexd_address
    indexd_user                   = var.db_indexd_username
    indexd_pwd                    = var.db_indexd_password
    indexd_db                     = var.db_indexd_name
    hostname                      = var.hostname
    google_client_secret          = var.google_client_secret
    google_client_id              = var.google_client_id
    hmac_encryption_key           = var.hmac_encryption_key
    sheepdog_secret_key           = var.sheepdog_secret_key
    sheepdog_indexd_password      = var.sheepdog_indexd_password
    sheepdog_oauth2_client_id     = var.sheepdog_oauth2_client_id
    sheepdog_oauth2_client_secret = var.sheepdog_oauth2_client_secret
    aws_user_key                  = var.aws_user_key
    aws_user_key_id               = var.aws_user_key_id
    indexd_prefix                 = var.indexd_prefix

    ## mailgun creds
    mailgun_api_key               = var.mailgun_api_key
    mailgun_api_url               = var.mailgun_api_url
    mailgun_smtp_host             = var.mailgun_smtp_host
  }
}

data "template_file" "configmap" {
  template = file("${path.module}/00configmap.yaml")

  vars {
    vpc_name       = var.vpc_name
    hostname       = var.hostname
    kube_bucket    = var.kube_bucket_name
    logs_bucket    = var.logs_bucket_name
    revproxy_arn   = var.ssl_certificate_id
    gitops_path    = var.gitops_path
  }
}

resource "null_resource" "config_setup" {
  triggers {
    creds_change  = data.template_file.creds.rendered
    config_change = data.template_file.configmap.rendered
  }

  provisioner "local-exec" {
    command = "mkdir -p ${var.vpc_name}_output; echo '${data.template_file.creds.rendered}' >${var.vpc_name}_output/creds.json"
  }

  provisioner "local-exec" {
    command = "echo \"${data.template_file.configmap.rendered}\" > ${var.vpc_name}_output/00configmap.yaml"
  }
}
