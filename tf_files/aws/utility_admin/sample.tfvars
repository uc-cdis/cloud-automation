
bootstrap_path             = "cloud-automation/flavors/adminvm/"
bootstrap_script           = "ubuntu-18-init.sh"
vm_name                    = "_admin"
vm_hostname                = "_admin"
vpc_cidr_list              = ["10.128.0.0/20", "52.0.0.0/8", "54.0.0.0/8", "172.x.y.0/20"]
aws_account_id             = "ACCOUNT-ID"
extra_vars                 = ["account_id=account_id"]
image_name_search_criteria ="ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"

