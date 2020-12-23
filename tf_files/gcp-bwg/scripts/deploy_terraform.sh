#!/bin/bash
# ---
# Plugin Name: Deploy Terraform Plugin
# Description: Installs Terraform
# Requires ENV Vars TERRAFORM_BINARY_URL
#               and TERRAFORM_ZIP
# Current URL https://releases.hashicorp.com/terraform/0.11.13/terraform_0.11.13_linux_amd64.zip
# Current ZIP terraform_0.11.13_linux_amd64.zip
# ...
set -euo pipefail
IFS=$'\\n\\t'
echo \"Installing Terraform...\"
sudo apt-get update
sudo apt-get install unzip git jq -y
wget $TERRAFORM_BINARY_URL
unzip $TERRAFORM_ZIP
chmod +x terraform
sudo mv terraform /usr/local/bin
terraform --version