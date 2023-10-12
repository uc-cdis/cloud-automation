terraform {
  backend "s3" {
    encrypt = "true"
  }
}

locals {
  sa_name           = "${var.service}-sa"
  sa_namespace      = var.namespace
  eks_oidc_issuer   = trimprefix(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://")
  database_name     = var.database_name != "" ? var.database_name : "${var.service}_${var.namespace}"
  database_username = var.username != "" ? var.username : "${var.service}_${var.namespace}"
  database_password = var.password != "" ? var.password : random_password.db_password[0].result
}

module "secrets_manager" {
  count       = var.secrets_manager_enabled ? 1 : 0
  source	    = "../modules/secrets_manager"
  vpc_name    = var.vpc_name
  secret	    = templatefile("${path.module}/secrets_manager.tftpl", {
    hostname = data.aws_db_instance.database.address
    database = local.database_name
    username = local.database_username
    password = local.database_password
  })
  secret_name = "${var.vpc_name}-${var.service}-creds"

  depends_on = [ null_resource.user_setup ]
}

resource "aws_iam_policy" "secrets_manager_policy" {
  count       = var.secrets_manager_enabled ? 1 : 0
  name        = "${var.vpc_name}-${var.service}-${var.namespace}-creds-access-policy"
  description = "Policy for ${var.vpc_name}-${var.service} to access secrets manager"
  policy      = data.aws_iam_policy_document.policy.json
}

resource "aws_iam_role" "role" {
  count              = var.secrets_manager_enabled ? var.role != "" ? 0 : 1 : 0
  name               = "${var.vpc_name}-${var.service}-${var.namespace}-creds-access-role"
  assume_role_policy = data.aws_iam_policy_document.sa_policy.json
}

resource "aws_iam_role_policy_attachment" "new_attach" {
  count      = var.secrets_manager_enabled ? 1 : 0
  role       = var.role != "" ? var.role : aws_iam_role.role[0].name
  policy_arn = aws_iam_policy.secrets_manager_policy[0].arn
}

resource "random_password" "db_password" {
  count            = var.password != "" ? 0 : 1
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "null_resource" "db_setup" {
    provisioner "local-exec" {
        command = "psql -h ${data.aws_db_instance.database.address} -U ${var.admin_database_username} -d ${var.admin_database_name} -c \"CREATE DATABASE \\\"${local.database_name}\\\";\""
        environment = {
          # for instance, postgres would need the password here:
          PGPASSWORD = var.admin_database_password != "" ? var.admin_database_password : data.aws_secretsmanager_secret_version.aurora-master-password.secret_string
        }
      on_failure = continue
    }

    triggers = {
        database = local.database_name
    }    
}

resource "null_resource" "user_setup" {

    provisioner "local-exec" {
        command = "psql -h ${data.aws_db_instance.database.address} -U ${var.admin_database_username} -d ${var.admin_database_name} -c \"${templatefile("${path.module}/db_setup.tftpl", {
          username  = local.database_username
          database  = local.database_name
          password  = local.database_password
        })}\""
        environment = {
          # for instance, postgres would need the password here:
          PGPASSWORD = var.admin_database_password != "" ? var.admin_database_password : data.aws_secretsmanager_secret_version.aurora-master-password.secret_string
        }
    }

    triggers = {
        username = local.database_username
        database = local.database_name
        password = local.database_password
    }

    depends_on = [ null_resource.db_setup ]
}

resource "null_resource" "db_restore" {
  count = var.db_restore && var.dump_file_to_restore != "" ? 1 : 0

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOF
# If we have a role to assume, then assume it and set the credentials
if [[ ${var.db_job_role_arn} != "" ]]; then
  CREDENTIALS=(`aws sts assume-role --role-arn ${var.db_job_role_arn} --role-session-name "db-migration-cli" --query "[Credentials.AccessKeyId,Credentials.SecretAccessKey,Credentials.SessionToken]" --output text`)
  unset AWS_PROFILE
  export AWS_DEFAULT_REGION=us-east-1
  export AWS_ACCESS_KEY_ID="$${CREDENTIALS[0]}"
  export AWS_SECRET_ACCESS_KEY="$${CREDENTIALS[1]}"
  export AWS_SESSION_TOKEN="$${CREDENTIALS[2]}"
fi

aws s3 cp "${var.dump_file_to_restore}" - --quiet | psql -h "${data.aws_db_instance.database.address}" -U "${local.database_username}" -d "${local.database_name}"
echo "Done restoring database"
EOF

        environment = {
          # for instance, postgres would need the password here:
          PGPASSWORD = local.database_password
        }
    }

    triggers = {
        username = local.database_username
        database = local.database_name
        password = local.database_password
    }

    depends_on = [ null_resource.user_setup ]
}

resource "null_resource" "db_dump" {
  count = var.db_dump && var.dump_file_storage_location != "" ? 1 : 0

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOF
# If we have a role to assume, then assume it and set the credentials
if [[ ${var.db_job_role_arn} != "" ]]; then
  CREDENTIALS=(`aws sts assume-role --role-arn ${var.db_job_role_arn} --role-session-name "db-migration-cli" --query "[Credentials.AccessKeyId,Credentials.SecretAccessKey,Credentials.SessionToken]" --output text`)
  unset AWS_PROFILE
  export AWS_DEFAULT_REGION=us-east-1
  export AWS_ACCESS_KEY_ID="$${CREDENTIALS[0]}"
  export AWS_SECRET_ACCESS_KEY="$${CREDENTIALS[1]}"
  export AWS_SESSION_TOKEN="$${CREDENTIALS[2]}"
fi
    
pg_dump --username="${local.database_username}" --dbname="${local.database_name}" --host="${data.aws_db_instance.database.address}" --no-password --no-owner --no-privileges >> ./dump.sql && aws s3 cp ./dump.sql ${var.dump_file_storage_location} && rm ./dump.sql
echo "Done restoring database"
EOF
    environment = {
      # for instance, postgres would need the password here:
      PGPASSWORD = local.database_password
    }
  }

  triggers = {
      username = local.database_username
      database = local.database_name
      password = local.database_password
  }

  depends_on = [ null_resource.user_setup ]
}