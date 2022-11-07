issuer_url="$(aws eks describe-cluster --name ${vpc_name} --query cluster.identity.oidc.issuer --output text)" || return 1
account_id=$(aws sts get-caller-identity --query Account --output text) || return 1

export TF_VAR_issuer_url="${issuer_url#https://}"
export TF_VAR_provider_arn="arn:aws:iam::${account_id}:oidc-provider/${issuer_url}"
export TF_VAR_namespace="$(gen3 db namespace)"