#
# Helper script for 'gen3 workon' - see ../README.md and ../gen3setup.sh
#

if [[ ! -f "$GEN3_HOME/gen3/lib/common.sh" ]]; then
  echo "ERROR: no $GEN3_HOME/gen3/lib/common.sh"
  exit 1
fi

help() {
  cat - <<EOM
  Use: gen3 workon aws-profile vpc-name
     Prepares a local workspace to run terraform and other devops tools.
EOM
  return 0
}

source "$GEN3_HOME/gen3/lib/common.sh"

#
# Create any missing files
#
mkdir -p -m 0700 "$GEN3_WORKDIR/backups"

#
# aws_provider.tfvars - this has the secret keys that
# the terraform aws provider wants:
#     https://www.terraform.io/docs/providers/aws/
#
if [[ ! -f "$GEN3_WORKDIR/aws_provider.tfvars" ]]; then
  echo "Creating $GEN3_WORKDIR/aws_provider.tfvars"
  cat - > "$GEN3_WORKDIR/aws_provider.tfvars" <<EOM
aws_access_key = "$(aws configure get "$GEN3_PROFILE.aws_access_key_id")"
aws_secret_key = "$(aws configure get "$GEN3_PROFILE.aws_secret_access_key")"
aws_region = "$(aws configure get "$GEN3_PROFILE.region")"
EOM
fi

#
# aws_backend.tfvars - this has the secret keys that
# the terraform S3 backend wants:
#     https://www.terraform.io/docs/backends/types/s3.html
#
if [[ ! -f "$GEN3_WORKDIR/aws_backend.tfvars" ]]; then
  echo "Creating $GEN3_WORKDIR/aws_backend.tfvars"
  cat - > "$GEN3_WORKDIR/aws_backend.tfvars" <<EOM
access_key = "$(aws configure get "$GEN3_PROFILE.aws_access_key_id")"
secret_key = "$(aws configure get "$GEN3_PROFILE.aws_secret_access_key")"
region = "$(aws configure get "$GEN3_PROFILE.region")"
EOM
fi


#
# Sync the given file with S3.
# Note that 'workon' only every copies from S3 to local,
# and only if a local copy does not already exist.
# See 'gen3 refresh' to pull down latest files from s3.
# We copy the local up to S3 at 'apply' time.
#
refreshFromS3() {
  local fileName
  local filePath
  fileName=$1
  if [[ -z $fileName ]]; then
    return 1
  fi
  filePath="${GEN3_WORKDIR}/$fileName"
  if [[ -f $filePath ]]; then
    echo "Ignoring S3 refresh for file that already exists: $fileName"
    return 1
  fi
  s3Path="s3://${S3_TERRAFORM}/${GEN3_VPC}/${fileName}"
  aws s3 cp "$s3Path" "$filePath" > /dev/null 2>&1
  if [[ ! -f "$filePath" ]]; then
    echo "No data at $s3Path"
    return 1
  fi
  return 0
}

#
# Let helper generates a random string of alphanumeric characters of length $1.
#
function random_alphanumeric() {
    base64 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c $1
}


#
# Generate an initial backend.tfvars file with intelligent defaults
# where possible.
#
backend.tfvars() {
  cat - <<EOM
bucket = "cdis-terraform-state"
encrypt = "true"
key = "$GEN3_VPC"
region = "$(aws configure get "$GEN3_PROFILE.region")"
EOM
}

README.md() {
  cat - <<EOM
# TL;DR

Any special notes about $GEN3_VPC

## Useful commands

* gen3 help
* gen3 tfoutput ssh_config >> ~/.ssh/config
* rsync -rtvOz ${GEN3_VPC}_output/ k8s_${GEN3_VPC}/${GEN3_VPC}_output

EOM
}

#
# Generate an initial config.tfvars file with intelligent defaults
# where possible.
#
config.tfvars() {
  cat - <<EOM
# VPC name is also used in DB name, so only alphanumeric characters
vpc_name="$GEN3_VPC"

aws_cert_name="YOUR.CERT.NAME"

db_size=10

hostname="YOUR.API.HOSTNAME"

# ssh key to be added to kube nodes
kube_ssh_key="$(cat ~/.ssh/id_rsa.pub | sed 's/\s*$//')"

google_client_secret="YOUR.GOOGLE.SECRET"
google_client_id="YOUR.GOOGLE.CLIENT"

# Following variables can be randomly generated passwords

hmac_encryption_key="$(random_alphanumeric 32 | base64)"

gdcapi_secret_key="$(random_alphanumeric 50)"

# don't use ( ) " ' { } < > @ in password
db_password_fence="$(random_alphanumeric 32)"

db_password_gdcapi="$(random_alphanumeric 32)"

db_password_indexd="$(random_alphanumeric 32)"

db_instance="db.t2.micro"

# password for write access to indexd
gdcapi_indexd_password="$(random_alphanumeric 32)"

fence_snapshot=""
gdcapi_snapshot=""
indexd_snapshot=""

kube_additional_keys = <<EOB
  - '"ssh-dss AAAAB3NzaC1kc3MAAACBAPfnMD7+UvFnOaQF00Xn636M1IiGKb7XkxJlQfq7lgyzWroUMwXFKODlbizgtoLmYToy0I4fUdiT4x22XrHDY+scco+3aDq+Nug+jaKqCkq+7Ms3owtProd0Jj6AWCFW+PPs0tGJiObieci4YqQavB299yFNn+jusIrDsqlrUf7xAAAAFQCi4wno2jigjedM/hFoEFiBR/wdlwAAAIBl6vTMb2yDtipuDflqZdA5f6rtlx4p+Dmclw8jz9iHWmjyE4KvADGDTy34lhle5r3UIou5o3TzxVtfy00Rvyd2aa4QscFiX5jZHQYnbIwwlQzguCiF/gtYNCIZit2B+R1p2XTR8URY7CWOTex4X4Lc88UEsM6AgXIpJ5KKn1pK2gAAAIAJD8p4AeJtnimJTKBdahjcRdDDedD3qTf8lr3g81K2uxxsLOudweYSZ1oFwP7RnZQK+vVE8uHhpkmfsy1wKCHrz/vLFAQfI47JDX33yZmBLtHjjfmYDdKVn36XKZ5XrO66vcbX2Jav9Hlqb6w/nekBx2nbJaZnHwlAp70RU13gyQ== renukarya@Renukas-MacBook-Pro.local"'
  - '"ssh-dss AAAAB3NzaC1kc3MAAACBAPfnMD7+UvFnOaQF00Xn636M1IiGKb7XkxJlQfq7lgyzWroUMwXFKODlbizgtoLmYToy0I4fUdiT4x22XrHDY+scco+3aDq+Nug+jaKqCkq+7Ms3owtProd0Jj6AWCFW+PPs0tGJiObieci4YqQavB299yFNn+jusIrDsqlrUf7xAAAAFQCi4wno2jigjedM/hFoEFiBR/wdlwAAAIBl6vTMb2yDtipuDflqZdA5f6rtlx4p+Dmclw8jz9iHWmjyE4KvADGDTy34lhle5r3UIou5o3TzxVtfy00Rvyd2aa4QscFiX5jZHQYnbIwwlQzguCiF/gtYNCIZit2B+R1p2XTR8URY7CWOTex4X4Lc88UEsM6AgXIpJ5KKn1pK2gAAAIAJD8p4AeJtnimJTKBdahjcRdDDedD3qTf8lr3g81K2uxxsLOudweYSZ1oFwP7RnZQK+vVE8uHhpkmfsy1wKCHrz/vLFAQfI47JDX33yZmBLtHjjfmYDdKVn36XKZ5XrO66vcbX2Jav9Hlqb6w/nekBx2nbJaZnHwlAp70RU13gyQ== renukarya@Renukas-MacBook-Pro.local"'
  - '"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC2d7DncA3QdZoxXzkIaU4xcPZ0IJ97roh4qF3gE1dse3H/aQ5V3lYZ9HuhVYm1UnMvNvKXIdvsHUPEmwe6s9X8Fj1fxpxuF+/C6d5+5raHffEAqU/YEFa0V8vxcSCedQoiDfJwzUA7NTcMBEFAH4MdTa4hmGnlwEeW4JWFiBmr2y5UVRfrZhM+DVdv5hxFQCyTjMXz4ZOmfMnvC6W/ZNzCersDES36Mo/nqHQWIH6Xd5BfOYWrs2zW/MZRUy4Yt9hFyuKizSt77SpjmBYGeagHS0TSti36nAduMbr3dkbvPF3JhbsXxlGpZgaYR51zjK5cQNEEj2hCExWD2pWUKOzD jeff@wireles-guest-16-34-212.uchicago.edu"'
  - '"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCw48loSG10QUtackRFsmxYXd3OezarZLuT7F+bxKYsj9rx2WEehDxg1xWESMSoHxGlHMSWpt0NMnBC2oqRz19wk3YjE/LoOaDXZmzc6UBVZo4dgItKV2+T9RaeAMkCgRcp4EsN2Rw+GNoT2whIH8jrAi2HhoNSau4Gi4zyQ2px7xBtKdco5qjQ1a6s1EMqFuOL0jqqmAqMHg4g+oZnPl9uRzZao4UKgao3ypdTP/hGVTZc4MXGOskHpyKuvorFqr/QUg0suEy6jN3Sj+qZ+ETLXFfDDKjjZsrVdR4GNcQ/sMtvhaMYudObNgNHU9yjVL5vmRBCNM06upj3RHtVx0/L rpowell@rpowell.local"'
  - '"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDJTr2yJtsOCsQpuKmqXmzC2itsUC1NAybH9IA3qga2Cx96+hMRLRs16vWTTJnf781UPC6vN1NkCJd/EVWD87D3AbxTF4aOKe3vh5fpsLnVI67ZYKsRl8VfOrIjB1KuNgBD1PrsDeSSjO+/sRCrIuxqNSdASBs5XmR6ZNwowF0tpFpVNmARrucCjSKqSec8VY2QneX6euXFKM2KJDsp0m+/xZqLVa/iUvBVplW+BGyPe+/ETlbEXe5VYlSukpl870wOJOX64kaHvfCaFe/XWH9uO+ScP0J/iWZpMefWyxCEzvPaDPruN+Ed7dMnePcvVB8gdX0Vf0pHyAzulnV0FNLL ssullivan@HPTemp"'
  - '"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDkJRaRKEl9mqTm1ZSWqO9KX3b/zl0cv6RUshS4eST42LkiLjcrH2atsh6IWnvPyy6cdG7c45ntdEEWJ9yXxMhuCKGbFyz6QIgb4h9ZDJqFtTq7w2IhqfsApXBUm6XmZJGQxzB/t96UQIP1rdV9zhkx1OT+2hIrKFiDiCY5H5skirepFjyQxfmThGl2s45ay4PDwL6Spmx3pdgJTVUijcgTff8ZAnARpDJTeVWc/oGZtRG68+/iaVisGnDEVrt2YaQek0p8bTVSuiLGoZ/RC0luoBSdBvrPgU+UKOQXpqTwdZWOug6v/yInwROAKUvElD6AOoJbXLnbhzG78llD47CP kyle@Kyles-MacBook-Pro.local"'
  - '"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDYe74TEoKYZm9cfCTAsjICaKUzAkh3/Y6mhzhhzYIqra0J5efQ+SJcDt7soOJ2qE1zOcGGvuA8belebkjOZDv50Mn5cEvaKsbpS9Poq0H02TzKby42pfV4TER1XbByuHC9eltsbn7efnmsdzcaY4uv2bMVXVauO0/XwHgoatVAeKvc+Gwkgx5BqiSI/MY+qDpldufL6f0hzsxFVlC/auJp+NWmKDjfCaS+mTBEezkXlg04ARjn3Pl68troK2uP2qXNESFgkBDTsLftM6p8cKIGjVLZI2+D4ayjbRbKWNQxS3L5CEeobzrovtls5bPSbsG/MxFdZC6EIbJH5h/6eYYj"'
  - '"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCk0Z6Iy3mhEqcZLotIJd6j0nhq1F709M8+ttwaDKRg11kYbtRHxRv/ATpY8PEaDlaU3UlRhCBunbKhFVEdMiOfyi90shFp/N6gKr3cIzc6GPmobrSmpmTuHJfOEQB1i3p+lbEqI1aRj9vR/Ug/anjWd2dg+VBIi4kgX1hKVrEd1CHxySRYkIo+NTTwzglzEmcmp+u63sLjHiHXU055H5D6YwL3ussRVKw8UePpTeGO3tD+Y0ogyqByYdQWWTHckTwuvjIOTZ9T5wvh7CPSXT/je6Ddsq5mRqUopvyGKjHWaxO2s7TI9taQAvISE9rH5KD4hceRa81hzu3ZqZRw4in8IuSw5r8eG4ODjTEl0DIqa0C+Ui+MjSkfAZki0DjBf/HJbWe0c06MEJBorLjs9DHPQ5AFJUQqN7wk29r665zoK3zBdZG/JDXccZmptSMKVS02TxxzAON7oG66c9Kn7Vq6MBYcE3Sz7dxydm6PtvFIqij9KTfJdE+yw2o9seywB5yFfPkL63+hYZUaDFeJvvQSq5+7X2Cltn+F05J+EiORU5wO5oQWV01a2Yf6RT3o/728aYfaPjkdubwbCDWkdo8FaRqmK1NdQ8IoFprBjrhyDFwIXMEuVPrCJOUjL+ksXLPvYw2truiPfDxWxcvkVOAl4myfQOP4YqGmQ/IumYUbAw== thanhnd@uchicago.edu"'
  - '"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC6vuAdqy0pOwC5rduYmnjHTUsk/ryt//aJXwdhsFbuEFxKyuHsZ2O9r4wqwqsVpHdQBh3mLPXNGo2MZFESNEoL1olzW3VxXXzpujGHDd/F9FmOpnAAFz90gh/TM3bnWLLVWF2j7SKw68jUgijc28SnKRNRXpKJLv6PN9qq8OMHaojnEzrsGMb69lMT8dro1Yk71c4z5FDDVckN9UVL7W03+PE/dN6AtNWMlIEWlgm6/UA9Og+w9VYQnhEylxMpmxdO0SAbkIrr3EPC16kRewfovQLZJsw2KRo4EK62Xyjem/M1nHuJo4KpldZCOupxfo6jZosO/5wpKF1j8rF6vPLkHFYNwR62zTrHZ58NVjYTRF927kW7KHEq0xDKSr5nj9a8zwDInM/DkMpNyme4Jm3e4DOSQ3mP+LYG9TywNmf9/rVjEVwBBxqGRi27ex6GWcLm4XB58Ud3fhf5O5BDdkLYD1eqlJE5M4UG5vP5C9450XxW5eHUi/QK2/eV+7RijrEtczlkakPVO7JdWDZ44tX9sjkAlLSvgxkn4xZSdfqm/aJBIHUpoEitkZf9kgioZdDz2xmBDScG3c3g5UfPDrMvSTyoMliPo7bTIjdT/R1XV27V8ByrewwK/IkS70UkbIpE3GNYBUIWJBdNPpgjQ5scMOvhEIjts2z4KKq1mUSzdQ== zac"'
  - '"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCfX+T2c3+iBP17DS0oPj93rcQH7OgTCKdjYS0f9s8sIKjErKCao0tRNy5wjBhAWqmq6xFGJeA7nt3UBJVuaGFbszIzs+yvjZYYVrJQdfl0yPbrKRMd/Ch77Jnqbu97Uyu8UxhGkzqEcxQrdBqhqkakhQULjcjZBnk0M1PrLwW+Pl1kRCnXnX/x3YzDR/Ltgjc57qjPbqz7+CBbuFo5OCYOY94pcXetHskvx1AAQ7ZT2c/F/p6vIH5jPKnCTjuqWuGoimp/alczLMO6n+aHgzqc9NKQUScxA0fCGxFeoEdd6b370E7j8xXMIA/xSmq8lFPam+fm3117nC4m29sRktoBI8YP4L7VPSkM/hLp/vRzVJf6U183GfvUSZPERrg+NvMeah9vgkTgzH0iN1+s2xPj6eFz7VUOQtLYTchMZ/qyyGhUzJznY0szocVd6iDbMAYm67R+QtgYEBD1hYrtUD052imb62nEXHFSL3V6369GaJ+k5BIUTGweOaUxGbJlb6fG2Aho4EWaigYRMtmlKgDFaCeJGjlQrFR9lKFzDBc3Af3RefPDVsavYGdQQRUAmueGjlks99Bvh2U53HQgQvc0iQg3ijey2YXBr6xFCMeG7MJZbPcrlQLXko4KygK94EcDPZnIH542CrtAySk/UxxwZv5u0dLsh7o+ZK9G6PO1+Q== reubenonrye@uchicago.edu"'
  - '"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCi6uv+jsUNpMXgP0CL2XZa5YgFFpoFj3vu7rCpKTvsCRoxfR/piv8PXIAlFCWLDOHb/jn1BBl+RuYDv74PcCac9sb97HKTstEE6M0aHjvYtHr1po5GSTXNHqILSmypDaafLr30nWRd2GymFUZbIFRfrcbzVn9K+DQ9Hkny5yvrra4OD+rhGHettUWOszxfFRVBpBHKNy87rKQbFcyYlnrNHwifInmNLA+sPkbuvx6Cvra7EoTPfsc04z1QyVKiN4IqyKrJnTO3adS3z+EoMHw7xEVvX7dVX9I8Fl095IL2mtH0FEpT89OcGzVLnM72NszFZMksNsi9i4By/FELT3zN rudyardrichter@socrates.local"'
EOB
EOM
}

for fileName in config.tfvars backend.tfvars README.md; do
  filePath="${GEN3_WORKDIR}/$fileName"
  if [[ ! -f "$filePath" ]]; then
    refreshFromS3 "$fileName"
    if [[ ! -f "$filePath" ]]; then
      echo "Variables not configured at $filePath"
      echo "Setting up initial contents - you must customize the file before running terraform"
      # Run the function that corresponds to $fileName
      $fileName > "$filePath"
    fi
  fi
done

if [[ ! -d "$GEN3_WORKDIR/.terraform" ]]; then
  echo "initializing terraform"
  cd "$GEN3_WORKDIR"
  echo "checking if $S3_TERRAFORM bucket exists"
  if ! aws s3 ls "s3://$S3_TERRAFORM" > /dev/null 2>&1; then
    echo "Creating $S3_TERRAFORM bucket"
    echo "NOTE: please verify that aws profile region matches backend.tfvars region:"
    echo "  aws profile region: $(aws configure get $GEN3_PROFILE.region)"
    echo "  terraform backend region: $(cat *backend.tfvars | grep region)"

    S3_POLICY=$(cat - <<EOM
  {
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }
EOM
)
    aws s3api create-bucket --acl private --bucket "$S3_TERRAFORM"
    sleep 5 # Avoid race conditions
    aws s3api put-bucket-encryption --bucket "$S3_TERRAFORM" --server-side-encryption-configuration "$S3_POLICY"
  fi
  terraform init --backend-config ./backend.tfvars -backend-config ./aws_backend.tfvars "$GEN3_HOME/tf_files/aws/"
fi
