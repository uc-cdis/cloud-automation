#!/bin/bash
#
# AWS helper function - test with `gen3 testsuite`
#

gen3_load "gen3/lib/utils"

#
# Run the given command with AWS credentials if necessary
# to support assume-role, mfa, etc
# Assumes AWS_PROFILE environment is set.
#
gen3_aws_run() {
  (
    export AWS_PROFILE="${AWS_PROFILE:-default}"
    local gen3CredsCache="${GEN3_CACHE_DIR}/${AWS_PROFILE}_creds.json"
    local cacheIsValid="no"
    local gen3AwsExpire
    local gen3AwsRole=$(aws configure get "${AWS_PROFILE}.role_arn")
    local gen3AwsMfa

    if [[ -z "$gen3AwsRole" ]]; then
      gen3AwsMfa=$(aws configure get "${AWS_PROFILE}.mfa_serial") || true
      if [[ -z "$gen3AwsMfa" ]]; then
        # No assume-role or mfa stuff going on - just run the command directly
        "$@"
        return $?
      fi
    fi
    
    local gen3AwsAccessKeyId
    local gen3AwsSecretAccessKey
    local gen3AwsSessionToken
    
    # Try to use cached creds if possible
    if [[ -f $gen3CredsCache ]]; then
      gen3AwsExpire=$(jq -r '.Credentials.Expiration' < $gen3CredsCache)
      
      if [[ "$gen3AwsExpire" =~ ^[0-9]+ && "$gen3AwsExpire" > "$(date -u +%Y-%m-%dT%H:%M)" ]]; then
        cacheIsValid="yes"
      fi
    fi
    if [[ "$cacheIsValid" != "yes" ]]; then
      # echo to stderr - avoid messing with output pipes ...
      echo -e "$(green_color "INFO: refreshing aws access token cache")" 1>&2
      if [[ -n "$gen3AwsRole" ]]; then
        # aws cli is smart about assume-role with MFA and everything - just need to get a new token
        # example ~/.aws/config entry:
        #
        # [profile cdistest]
        # output = json
        # region = us-east-1
        # role_arn = arn:aws:iam::707767160287:role/csoc_adminvm
        # role_session_name = gen3-reuben
        # source_profile = csoc
        # mfa_serial = arn:aws:iam::433568766270:mfa/reuben-csoc
        #
        # or
        #
        # [profile cdistest]
        # output = json
        # region = us-east-1
        # role_arn = arn:aws:iam::707767160287:role/csoc_adminvm
        # role_session_name = gen3-reuben
        # credential_source = Ec2InstanceMetadata
        #
        aws sts assume-role --role-arn "${gen3AwsRole}" --role-session-name "gen3-$USER" > "$gen3CredsCache"
      else
        # zsh does not like 'read -p'
        printf '%s: ' "Enter a token from the $AWS_PROFILE MFA device $gen3AwsMfa" 1>&2
        read mfaToken
        aws sts get-session-token --serial-number "$gen3AwsMfa" --token-code "$mfaToken" > "$gen3CredsCache"
      fi
    fi
    
    if [[ ! -f "$gen3CredsCache" ]]; then
      echo -e "$(red_color "ERROR: AWS creds not cached at $gen3CredsCache")" 1>&2
      return 1
    fi
    gen3AwsAccessKeyId=$(jq -r '.Credentials.AccessKeyId' < $gen3CredsCache)
    gen3AwsSecretAccessKey=$(jq -r '.Credentials.SecretAccessKey' < $gen3CredsCache)
    gen3AwsSessionToken=$(jq -r '.Credentials.SessionToken' < $gen3CredsCache)
    AWS_ACCESS_KEY_ID="$gen3AwsAccessKeyId" AWS_SECRET_ACCESS_KEY="$gen3AwsSecretAccessKey" AWS_SESSION_TOKEN="$gen3AwsSessionToken" "$@"
  )
  return $?
}

#
# Setup and access terraform workspace for AWS - 
#   delegate for `gen3 workon ...`
#
gen3_workon_aws(){
  if ! ( aws configure get "${1}.region" > /dev/null ); then
    echo -e "$(red_color "PROFILE $1 not properly configured with default region for aws cli")"
    return 3
  fi
  export GEN3_PROFILE="$1"
  export GEN3_WORKSPACE="$2"
  export GEN3_FLAVOR=AWS
  export GEN3_WORKDIR="$XDG_DATA_HOME/gen3/${GEN3_PROFILE}/${GEN3_WORKSPACE}"
  export AWS_PROFILE="$GEN3_PROFILE"
  export AWS_DEFAULT_REGION=$(aws configure get "${AWS_PROFILE}.region")  
  export AWS_ACCOUNT_ID=$(gen3_aws_run aws sts get-caller-identity | jq -r .Account)

  # S3 bucket where we save terraform state, etc
  if [[ -z "$AWS_ACCOUNT_ID" ]]; then
    echo "Error: unable to determine AWS_ACCOUNT_ID via: aws sts get-caller-identity | jq -r .Account"
    export GEN3_S3_BUCKET=""
  else
    #
    # This is the new bucket name, which we prefer if data doesn't already exist in the old bucket ...
    #    https://docs.aws.amazon.com/AmazonS3/latest/dev/BucketRestrictions.html#bucketnamingrules
    #
    export GEN3_S3_BUCKET="cdis-state-ac${AWS_ACCOUNT_ID}-gen3"
    
    OLD_S3_BUCKET="cdis-terraform-state.account-${AWS_ACCOUNT_ID}.gen3"
    if (! gen3_aws_run aws s3 ls "s3://${GEN3_S3_BUCKET}/${GEN3_WORKSPACE}" > /dev/null 2>&1) &&
      (gen3_aws_run aws s3 ls "s3://${OLD_S3_BUCKET}/${GEN3_WORKSPACE}" > /dev/null 2>&1)
    then
      # Use the old bucket ... 
      export GEN3_S3_BUCKET="${OLD_S3_BUCKET}"
    fi
  fi

  # terraform stack - based on VPC name
  export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/aws/commons"
  if [[ "$GEN3_WORKSPACE" =~ _user$ ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/aws/user_vpc"
  elif [[ "$GEN3_WORKSPACE" =~ _snapshot$ ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/aws/rds_snapshot"
  elif [[ "$GEN3_WORKSPACE" =~ _adminvm$ ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/aws/csoc_admin_vm"
  elif [[ "$GEN3_WORKSPACE" =~ _logging$ ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/aws/csoc_common_logging"
  elif [[ "$GEN3_WORKSPACE" =~ _databucket$ ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/aws/data_bucket"
  elif [[ "$GEN3_WORKSPACE" =~ _squidvm$ ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/aws/squid_vm"
  elif [[ "$GEN3_WORKSPACE" =~ _utilityvm$ ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/aws/utility_vm"
  elif [[ "$GEN3_WORKSPACE" =~ _bigdisk$ ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/aws/worker_bigdisk"
  elif [[ "$GEN3_WORKSPACE" =~ _squidnlbcentral$ ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/aws/squid_nlb_central"
  elif [[ "$GEN3_WORKSPACE" =~ _squidnlb$ ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/aws/squidnlb_standalone"
  elif [[ "$GEN3_WORKSPACE" =~ _es$ ]]; then
    export GEN3_TFSCRIPT_FOLDER="${GEN3_HOME}/tf_files/aws/commons_vpc_es"
  fi

  PS1="gen3/${GEN3_WORKSPACE}:$GEN3_PS1_OLD"
  return 0
}

#
# Generate an initial backend.tfvars file with intelligent defaults
# where possible.
#
gen3_AWS.backend.tfvars() {
  cat - <<EOM
bucket = "$GEN3_S3_BUCKET"
encrypt = "true"
key = "$GEN3_WORKSPACE/terraform.tfstate"
region = "$(aws configure get "$GEN3_PROFILE.region")"
EOM
}

README.md() {
  cat - <<EOM
# TL;DR

Any special notes about $GEN3_WORKSPACE

## Useful commands

* gen3 help

EOM
}


#
# Generate an initial config.tfvars file with intelligent defaults
# where possible.
#
gen3_AWS.config.tfvars() {
  local commonsName

  if [[ "$GEN3_WORKSPACE" =~ _user$ ]]; then
    # user vpc is simpler ...
    cat - <<EOM
vpc_name="$GEN3_WORKSPACE"
#
# for vpc_octet see https://github.com/uc-cdis/cdis-wiki/blob/master/ops/AWS-Accounts.md
#  CIDR becomes 172.{vpc_octet2}.{vpc_octet3}.0/20
#
vpc_octet2=GET_A_UNIQUE_VPC_172_OCTET2
vpc_octet3=GET_A_UNIQUE_VPC_172_OCTET3


ssh_public_key="$(sed 's/\s*$//' ~/.ssh/id_rsa.pub)"
EOM
    return 0
  fi

  # else ...
  if [[ "$GEN3_WORKSPACE" =~ _snapshot$ ]]; then
    # rds snapshot vpc is simpler ...
    commonsName=$(echo "$GEN3_WORKSPACE" | sed 's/_snapshot$//')
    cat - <<EOM
vpc_name="${commonsName}"
indexd_rds_id="${commonsName}-indexddb"
fence_rds_id="${commonsName}-fencedb"
sheepdog_rds_id="${commonsName}-gdcapidb"
EOM
    return 0
  fi

  # else
  if [[ "$GEN3_WORKSPACE" =~ _adminvm$ ]]; then
    # rds snapshot vpc is simpler ...
    commonsName=$(echo "$GEN3_WORKSPACE" | sed 's/_snapshot$//')
    cat - <<EOM
child_account_id="ACCOUNT-ID"
child_name="NAME FOR TAGGING"
vpc_cidr_list=[ "CIDR1", "CIDR2"]
EOM
    return 0
  fi

    # else
  if [[ "$GEN3_WORKSPACE" =~ _squidvm$ ]]; then
    # rds snapshot vpc is simpler ...
    commonsName=$(echo "$GEN3_WORKSPACE" | sed 's/_snapshot$//')
    cat - <<EOM
  env_vpc_name         = "VPC-NAME"
  env_vpc_id           = "VPC-ID"
  env_vpc_cidr         = "VPC-CIDR"
  env_public_subnet_id = "VPC-PUBLIC-SUBNET"
EOM
    return 0
  fi
  
  if [[ "$GEN3_WORKSPACE" =~ _logging$ ]]; then
    # rds snapshot vpc is simpler ...
    commonsName=$(echo "$GEN3_WORKSPACE" | sed 's/_logging$//')
    cat - <<EOM
child_account_id="NUMERIC-ID"
common_name="${commonsName}"
EOM
    return 0
  fi

  # else ...
  if [[ "$GEN3_WORKSPACE" =~ _databucket$ ]]; then
    cat - <<EOM
bucket_name="$(echo "$GEN3_WORKSPACE" | sed 's/[_\.]/-/g')-gen3"
environment="$(echo "$GEN3_WORKSPACE" | sed 's/_databucket$//')"
EOM
    return 0
  fi

  # else ...
  if [[ "$GEN3_WORKSPACE" =~ _utilityvm$ ]]; then
     #vmName=$(echo "$GEN3_WORKSPACE" | sed 's/_utilityvm$//')
     vmName=${GEN3_WORKSPACE//_utilityvm/}
     cat - <<EOM
bootstrap_path = "cloud-automation/flavors/"
bootstrap_script = "FILE-IN-ABOVE-PATH"
vm_name = "${vmName}"
vm_hostname = "${vmName}"
vpc_cidr_list = ["10.128.0.0/20", "52.0.0.0/8", "54.0.0.0/8"]
extra_vars = []
EOM
    return 0
  fi

  # else ...
  if [[ "$GEN3_WORKSPACE" =~ _bigdisk$ ]]; then
    cat - <<EOM
volume_size = 20
instance_ip = "10.0.0.0"
dev_name = "/dev/sdz"
EOM
    return 0
  fi

  # else ...
  if [[ "$GEN3_WORKSPACE" =~ _squidnlbcentral$ ]]; then
    # rds snapshot vpc is simpler ...
    commonsName=$(echo "$GEN3_WORKSPACE" | sed 's/_snapshot$//')
    cat - <<EOM
  env_vpc_octet3                = "3rd OCTET OF CSOC CIDR FOR SQUID SETUP"
  env_nlb_name                  = "NLB SETUP NAME"
  # CSOC MAIN VPC ID 
  env_vpc_id                    = "vpc-e2b51d99"
  # CSOC ROUTE TABLE ID - HAVING ROUTE TO INTERNET GW
  env_pub_subnet_routetable_id = "rtb-1cb66860"
  # internal.io DNS ZONE ID IN CSOC MAIN VPC"
  csoc_internal_dns_zone_id  = "ZA1HVV5W0QBG1"
  # LIST OF AWS ACCOUNTS WHICH NEEDS TO BE WHITELISTED
  allowed_principals_list       = ["arn:aws:iam::707767160287:root", "arn:aws:iam::655886864976:root", "arn:aws:iam::663707118480:root", "arn:aws:iam::728066667777:root", "arn:aws:iam::433568766270:root" , "arn:aws:iam::733512436101:root", "arn:aws:iam::584476192960:root", "arn:aws:iam::803291393429:root", "arn:aws:iam::980870151884:root", "arn:aws:iam::562749638216:root", "arn:aws:iam::302170346065:root", "arn:aws:iam::636151780898:root", "arn:aws:iam::895962626746:root", "arn:aws:iam::369384647397:root", "arn:aws:iam::547481746681:root", "arn:aws:iam::053927701465:root"]
  # e.g. of the list - ["arn:aws:iam::<AWS ACCOUNT1 ID>:root","arn:aws:iam::<AWS ACCOUNT2 ID>:root", ...]
EOM
    return 0
  fi

  # else ...
  if [[ "$GEN3_WORKSPACE" =~ _squidnlb$ ]]; then
    # rds snapshot vpc is simpler ...
    commonsName=$(echo "$GEN3_WORKSPACE" | sed 's/_snapshot$//')
    cat - <<EOM
  env_vpc_octet1                = "1st OCTET OF VPC CIDR FOR SQUID SETUP"
  env_vpc_octet2                = "2nd OCTET OF VPC CIDR FOR SQUID SETUP"
  env_vpc_octet3                = "3rd OCTET OF VPC CIDR FOR SQUID SETUP"
  ## The code takes the third octet ; adds 15 to it and uses the CIDR as squid nlb cluster CIDR ; Eg. if your VPC CIDR is 10.128.0.0/20 ; it coverts it to 10.128.15.0/24 and thats your squid cluster CIDR
  env_nlb_name                  = "NLB SETUP NAME"
  env_vpc_id                    = "COMMONS VPC-ID"
  env_public_subnet_routetable_id = "COMMONS ROUTE TABLE (MAIN) ID  - HAVING ROUTE TO INTERNET GW"
  commons_internal_dns_zone_id  = "PUT IT AS `ZA1HVV5W0QBG1` IF LAUNCHING THE SQUID NLB IN CSOC MAIN VPC"
  # allowed_principals_list       = "[LIST OF AWS ACCOUNTS WHICH NEEDS TO BE WHITELISTED]"
  # e.g. of the list - ["arn:aws:iam::<AWS ACCOUNT1 ID>:root","arn:aws:iam::<AWS ACCOUNT2 ID>:root", ...]
EOM
    return 0
  fi

  # else ...
  if [[ "$GEN3_WORKSPACE" =~ _es ]]; then
      commonsName=${GEN3_WORKSPACE//_es/}
      cat - <<EOM
vpc_name   = "${commonsName}"
vpc_id     = "COMMONS VPC-ID"
vpc_octet2 = "2nd OCTECT"
vpc_octet3 = "3rd OCTECT"
EOM
    return 0
  fi


  # ssh key to be added to VMs and kube nodes
  local SSHADD=$(which ssh-add)
  if [ -f ~/.ssh/id_rsa.pub ];
  then
    kube_ssh_key="$(sed 's/\s*$//' ~/.ssh/id_rsa.pub)"
  elif [ ! -z "$(${SSHADD} -L)" ];
  then
    kube_ssh_key="$(${SSHADD} -L)"
  else
    kube_ssh_key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDOHPLoBC42tbr7YiQHGRWDOZ+5ItJVhgSqAOOb8bHD65ajen1haM2PUvqCrZ0p7NOrDPFRBlNIRlhC2y3VdnKkNYSYMvHUEwt8+V3supJBj2Tu8ldzpQthDu345/Ge4hqwp+ujZVRfjjAFaFLkMtqvlAXkj7a2Ip6ZZEhd8NcRq/mQET3eCaBR5/+BGzEMBVQGTSGYOY5rOkR8PNQiX+BF7qIX/xRHo8GCOztO4KmDLmaZV63ovQwr01PXSGEq/VGfHwXAvzX13IXTYE2gechEyudhRGZBbhayyaKD7VRoKzd4BZuuUrLCSpMDWBK/qtECcP4pCXW/0Wi2OCzUen3syh/YrOtJD1CUO+VvW6/8xFrcBeoygFW87hW08ncXLT/XxpgWeExJrTGIxjr4YzcsWPBzxI7/4SmKbaDSjx/RMX7x5WbPc5AZzHY17cKcpdc14weG+sm2OoKF5RqnFB/JpBaNxG+Zq8qYC/6h8fOzDWo5+qWKO/UlWaa3ob2QpG8qOBskoyKVG3ortQ04E04DmoaOiSsXoj0U0zaJnxpdF+a0i31RxQnjckTMEHH8Y2Ow8KIG45tzhJx9NbqSj9abk3yTzGA7MHvugQFpuTQ3gaorfG+A9RGUmx6aQNwXUGu+DWRF7lFeaPJt4CDjzbDUGP/b5KJkWK0DDAI61JfOew== /home/fauzi/.ssh/id_rsa"
  fi

local db_password_sheepdog
db_password_sheepdog="$(random_alphanumeric 32)"
cat - <<EOM
# VPC name is also used in DB name, so only alphanumeric characters
vpc_name="$GEN3_WORKSPACE"
#
# for vpc_octet see https://github.com/uc-cdis/cdis-wiki/blob/master/ops/AWS-Accounts.md
#  CIDR becomes 172.{vpc_octet2}.{vpc_octet3}.0/20
#
vpc_octet2=GET_A_UNIQUE_VPC_172_OCTET2
vpc_octet3=GET_A_UNIQUE_VPC_172_OCTET3
dictionary_url="https://s3.amazonaws.com/dictionary-artifacts/YOUR/DICTIONARY/schema.json"
portal_app="dev"

aws_cert_name="arn:aws:acm:REGION:ACCOUNT-NUMBER:certificate/CERT-ID"

db_size=10

hostname="YOUR.API.HOSTNAME"
#
# Bucket in bionimbus account hosts user.yaml
# config for all commons:
#   s3://cdis-gen3-users/CONFIG_FOLDER/user.yaml
#
config_folder="PUT-SOMETHING-HERE"

google_client_secret="YOUR.GOOGLE.SECRET"
google_client_id="YOUR.GOOGLE.CLIENT"

# Following variables can be randomly generated passwords

hmac_encryption_key="$(random_alphanumeric 32 | base64)"

gdcapi_secret_key="$(random_alphanumeric 50)"

# don't use ( ) " ' { } < > @ in password
db_password_fence="$(random_alphanumeric 32)"

db_password_gdcapi="$db_password_sheepdog"
db_password_sheepdog="$db_password_sheepdog"
db_password_peregrine="$(random_alphanumeric 32)"

db_password_indexd="$(random_alphanumeric 32)"

db_instance="db.t2.micro"

# password for write access to indexd
gdcapi_indexd_password="$(random_alphanumeric 32)"

fence_snapshot=""
gdcapi_snapshot=""
indexd_snapshot=""

kube_ssh_key="${kube_ssh_key}"

kube_additional_keys = <<EOB
  - '"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDiVYoa9i91YL17xWF5kXpYh+PPTriZMAwiJWKkEtMJvyFWGv620FmGM+PczcQN47xJJQrvXOGtt/n+tW1DP87w2rTPuvsROc4pgB7ztj1EkFC9VkeaJbW/FmWxrw2z9CTHGBoxpBgfDDLsFzi91U2dfWxRCBt639sLBfJxHFo717Xg7L7PdFmFiowgGnqfwUOJf3Rk8OixnhEA5nhdihg5gJwCVOKty8Qx73fuSOAJwKntcsqtFCaIvoj2nOjqUOrs++HG6+Fe8tGLdS67/tvvgW445Ik5JZGMpa9y0hJxmZj1ypsZv/6cZi2ohLEBCngJO6d/zfDzP48Beddv6HtL rarya"'
  - '"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC2d7DncA3QdZoxXzkIaU4xcPZ0IJ97roh4qF3gE1dse3H/aQ5V3lYZ9HuhVYm1UnMvNvKXIdvsHUPEmwe6s9X8Fj1fxpxuF+/C6d5+5raHffEAqU/YEFa0V8vxcSCedQoiDfJwzUA7NTcMBEFAH4MdTa4hmGnlwEeW4JWFiBmr2y5UVRfrZhM+DVdv5hxFQCyTjMXz4ZOmfMnvC6W/ZNzCersDES36Mo/nqHQWIH6Xd5BfOYWrs2zW/MZRUy4Yt9hFyuKizSt77SpjmBYGeagHS0TSti36nAduMbr3dkbvPF3JhbsXxlGpZgaYR51zjK5cQNEEj2hCExWD2pWUKOzD jeff@wireles-guest-16-34-212.uchicago.edu"'
  - '"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCw48loSG10QUtackRFsmxYXd3OezarZLuT7F+bxKYsj9rx2WEehDxg1xWESMSoHxGlHMSWpt0NMnBC2oqRz19wk3YjE/LoOaDXZmzc6UBVZo4dgItKV2+T9RaeAMkCgRcp4EsN2Rw+GNoT2whIH8jrAi2HhoNSau4Gi4zyQ2px7xBtKdco5qjQ1a6s1EMqFuOL0jqqmAqMHg4g+oZnPl9uRzZao4UKgao3ypdTP/hGVTZc4MXGOskHpyKuvorFqr/QUg0suEy6jN3Sj+qZ+ETLXFfDDKjjZsrVdR4GNcQ/sMtvhaMYudObNgNHU9yjVL5vmRBCNM06upj3RHtVx0/L rpowell@rpowell.local"'
  - '"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDJTr2yJtsOCsQpuKmqXmzC2itsUC1NAybH9IA3qga2Cx96+hMRLRs16vWTTJnf781UPC6vN1NkCJd/EVWD87D3AbxTF4aOKe3vh5fpsLnVI67ZYKsRl8VfOrIjB1KuNgBD1PrsDeSSjO+/sRCrIuxqNSdASBs5XmR6ZNwowF0tpFpVNmARrucCjSKqSec8VY2QneX6euXFKM2KJDsp0m+/xZqLVa/iUvBVplW+BGyPe+/ETlbEXe5VYlSukpl870wOJOX64kaHvfCaFe/XWH9uO+ScP0J/iWZpMefWyxCEzvPaDPruN+Ed7dMnePcvVB8gdX0Vf0pHyAzulnV0FNLL ssullivan@HPTemp"'
  - '"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDkJRaRKEl9mqTm1ZSWqO9KX3b/zl0cv6RUshS4eST42LkiLjcrH2atsh6IWnvPyy6cdG7c45ntdEEWJ9yXxMhuCKGbFyz6QIgb4h9ZDJqFtTq7w2IhqfsApXBUm6XmZJGQxzB/t96UQIP1rdV9zhkx1OT+2hIrKFiDiCY5H5skirepFjyQxfmThGl2s45ay4PDwL6Spmx3pdgJTVUijcgTff8ZAnARpDJTeVWc/oGZtRG68+/iaVisGnDEVrt2YaQek0p8bTVSuiLGoZ/RC0luoBSdBvrPgU+UKOQXpqTwdZWOug6v/yInwROAKUvElD6AOoJbXLnbhzG78llD47CP kyle@Kyles-MacBook-Pro.local"'
  - '"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDYe74TEoKYZm9cfCTAsjICaKUzAkh3/Y6mhzhhzYIqra0J5efQ+SJcDt7soOJ2qE1zOcGGvuA8belebkjOZDv50Mn5cEvaKsbpS9Poq0H02TzKby42pfV4TER1XbByuHC9eltsbn7efnmsdzcaY4uv2bMVXVauO0/XwHgoatVAeKvc+Gwkgx5BqiSI/MY+qDpldufL6f0hzsxFVlC/auJp+NWmKDjfCaS+mTBEezkXlg04ARjn3Pl68troK2uP2qXNESFgkBDTsLftM6p8cKIGjVLZI2+D4ayjbRbKWNQxS3L5CEeobzrovtls5bPSbsG/MxFdZC6EIbJH5h/6eYYj"'
  - '"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCk0Z6Iy3mhEqcZLotIJd6j0nhq1F709M8+ttwaDKRg11kYbtRHxRv/ATpY8PEaDlaU3UlRhCBunbKhFVEdMiOfyi90shFp/N6gKr3cIzc6GPmobrSmpmTuHJfOEQB1i3p+lbEqI1aRj9vR/Ug/anjWd2dg+VBIi4kgX1hKVrEd1CHxySRYkIo+NTTwzglzEmcmp+u63sLjHiHXU055H5D6YwL3ussRVKw8UePpTeGO3tD+Y0ogyqByYdQWWTHckTwuvjIOTZ9T5wvh7CPSXT/je6Ddsq5mRqUopvyGKjHWaxO2s7TI9taQAvISE9rH5KD4hceRa81hzu3ZqZRw4in8IuSw5r8eG4ODjTEl0DIqa0C+Ui+MjSkfAZki0DjBf/HJbWe0c06MEJBorLjs9DHPQ5AFJUQqN7wk29r665zoK3zBdZG/JDXccZmptSMKVS02TxxzAON7oG66c9Kn7Vq6MBYcE3Sz7dxydm6PtvFIqij9KTfJdE+yw2o9seywB5yFfPkL63+hYZUaDFeJvvQSq5+7X2Cltn+F05J+EiORU5wO5oQWV01a2Yf6RT3o/728aYfaPjkdubwbCDWkdo8FaRqmK1NdQ8IoFprBjrhyDFwIXMEuVPrCJOUjL+ksXLPvYw2truiPfDxWxcvkVOAl4myfQOP4YqGmQ/IumYUbAw== thanhnd@uchicago.edu"'
  - '"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC6vuAdqy0pOwC5rduYmnjHTUsk/ryt//aJXwdhsFbuEFxKyuHsZ2O9r4wqwqsVpHdQBh3mLPXNGo2MZFESNEoL1olzW3VxXXzpujGHDd/F9FmOpnAAFz90gh/TM3bnWLLVWF2j7SKw68jUgijc28SnKRNRXpKJLv6PN9qq8OMHaojnEzrsGMb69lMT8dro1Yk71c4z5FDDVckN9UVL7W03+PE/dN6AtNWMlIEWlgm6/UA9Og+w9VYQnhEylxMpmxdO0SAbkIrr3EPC16kRewfovQLZJsw2KRo4EK62Xyjem/M1nHuJo4KpldZCOupxfo6jZosO/5wpKF1j8rF6vPLkHFYNwR62zTrHZ58NVjYTRF927kW7KHEq0xDKSr5nj9a8zwDInM/DkMpNyme4Jm3e4DOSQ3mP+LYG9TywNmf9/rVjEVwBBxqGRi27ex6GWcLm4XB58Ud3fhf5O5BDdkLYD1eqlJE5M4UG5vP5C9450XxW5eHUi/QK2/eV+7RijrEtczlkakPVO7JdWDZ44tX9sjkAlLSvgxkn4xZSdfqm/aJBIHUpoEitkZf9kgioZdDz2xmBDScG3c3g5UfPDrMvSTyoMliPo7bTIjdT/R1XV27V8ByrewwK/IkS70UkbIpE3GNYBUIWJBdNPpgjQ5scMOvhEIjts2z4KKq1mUSzdQ== zac"'
  - '"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCfX+T2c3+iBP17DS0oPj93rcQH7OgTCKdjYS0f9s8sIKjErKCao0tRNy5wjBhAWqmq6xFGJeA7nt3UBJVuaGFbszIzs+yvjZYYVrJQdfl0yPbrKRMd/Ch77Jnqbu97Uyu8UxhGkzqEcxQrdBqhqkakhQULjcjZBnk0M1PrLwW+Pl1kRCnXnX/x3YzDR/Ltgjc57qjPbqz7+CBbuFo5OCYOY94pcXetHskvx1AAQ7ZT2c/F/p6vIH5jPKnCTjuqWuGoimp/alczLMO6n+aHgzqc9NKQUScxA0fCGxFeoEdd6b370E7j8xXMIA/xSmq8lFPam+fm3117nC4m29sRktoBI8YP4L7VPSkM/hLp/vRzVJf6U183GfvUSZPERrg+NvMeah9vgkTgzH0iN1+s2xPj6eFz7VUOQtLYTchMZ/qyyGhUzJznY0szocVd6iDbMAYm67R+QtgYEBD1hYrtUD052imb62nEXHFSL3V6369GaJ+k5BIUTGweOaUxGbJlb6fG2Aho4EWaigYRMtmlKgDFaCeJGjlQrFR9lKFzDBc3Af3RefPDVsavYGdQQRUAmueGjlks99Bvh2U53HQgQvc0iQg3ijey2YXBr6xFCMeG7MJZbPcrlQLXko4KygK94EcDPZnIH542CrtAySk/UxxwZv5u0dLsh7o+ZK9G6PO1+Q== reubenonrye@uchicago.edu"'
  - '"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCi6uv+jsUNpMXgP0CL2XZa5YgFFpoFj3vu7rCpKTvsCRoxfR/piv8PXIAlFCWLDOHb/jn1BBl+RuYDv74PcCac9sb97HKTstEE6M0aHjvYtHr1po5GSTXNHqILSmypDaafLr30nWRd2GymFUZbIFRfrcbzVn9K+DQ9Hkny5yvrra4OD+rhGHettUWOszxfFRVBpBHKNy87rKQbFcyYlnrNHwifInmNLA+sPkbuvx6Cvra7EoTPfsc04z1QyVKiN4IqyKrJnTO3adS3z+EoMHw7xEVvX7dVX9I8Fl095IL2mtH0FEpT89OcGzVLnM72NszFZMksNsi9i4By/FELT3zN rudyardrichter@socrates.local"'
  - '"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDOHPLoBC42tbr7YiQHGRWDOZ+5ItJVhgSqAOOb8bHD65ajen1haM2PUvqCrZ0p7NOrDPFRBlNIRlhC2y3VdnKkNYSYMvHUEwt8+V3supJBj2Tu8ldzpQthDu345/Ge4hqwp+ujZVRfjjAFaFLkMtqvlAXkj7a2Ip6ZZEhd8NcRq/mQET3eCaBR5/+BGzEMBVQGTSGYOY5rOkR8PNQiX+BF7qIX/xRHo8GCOztO4KmDLmaZV63ovQwr01PXSGEq/VGfHwXAvzX13IXTYE2gechEyudhRGZBbhayyaKD7VRoKzd4BZuuUrLCSpMDWBK/qtECcP4pCXW/0Wi2OCzUen3syh/YrOtJD1CUO+VvW6/8xFrcBeoygFW87hW08ncXLT/XxpgWeExJrTGIxjr4YzcsWPBzxI7/4SmKbaDSjx/RMX7x5WbPc5AZzHY17cKcpdc14weG+sm2OoKF5RqnFB/JpBaNxG+Zq8qYC/6h8fOzDWo5+qWKO/UlWaa3ob2QpG8qOBskoyKVG3ortQ04E04DmoaOiSsXoj0U0zaJnxpdF+a0i31RxQnjckTMEHH8Y2Ow8KIG45tzhJx9NbqSj9abk3yTzGA7MHvugQFpuTQ3gaorfG+A9RGUmx6aQNwXUGu+DWRF7lFeaPJt4CDjzbDUGP/b5KJkWK0DDAI61JfOew== fauzi@uchicago.edu"'
EOB
EOM
}
