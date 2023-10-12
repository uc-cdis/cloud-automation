
# id of AWS account that owns the public AMI's
variable "ami_account_id" {
  description = "AWS account id of who owns the AMI"
  # by default lets use canonical stuff only
  default = "099720109477"
}

variable "aws_account_id" {
  description = "AWS account id where the VM is going to be deployed"
  default     = "433568766270"
}

variable "aws_region" {
  description = "AWS region where the VM will be deployed"
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC id where the VM will live"
  default     = "vpc-e2b51d99"
}

variable "vpc_subnet_id" {
  description = "Subnet id where the VM will live"
  default = "subnet-6127013c"
}

variable "vpc_cidr_list" {
  description = "CIDRs that will skip the proxy"
  type        = list(string)
  default     = ["10.128.0.0/20", "54.0.0.0/8", "52.0.0.0/8"]
}

# name of aws_key_pair ssh key to attach to VM's
variable "ssh_key_name" {
  description = "SSH key required to deploy the VM"
}

variable "environment" {
  description = "For tagging purposes"
  default     = "CSOC"
}

variable "instance_type" {
  description = "Instance type to be deploy the VM on"
  default     = "t3.micro"
}

variable "image_name_search_criteria" {
  description = "Searc criteria for the AMI"
  default     = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"
}

variable "extra_vars" {
  description = "List of variables that terraform will send to the bootstrapscript"
  type        = list(string)
}

variable "bootstrap_path" {
  description = "Path where the bootstrap script it'll run after user_data portion is complete"
}

variable "bootstrap_script" {
  description = "The actual bootstrap script"
}

variable "vm_name" {
  description = "Name for the VM"
}

variable "vm_hostname" {
  description = "Hostname for the VM"
}

variable "proxy" {
  description = "if the VM is going to be behind a proxy"
  default     = true
}

variable "authorized_keys" {
  description = "Before the bootstrap script kicks in, the authorized_keys file for ubuntu will be updated with this file"
  default     = "files/authorized_keys/ops_team"
}

variable "organization_name" {
  description = "For tagging purposes"
  default     = "Basic Service"
}

variable "branch" {
  description = "For testing purposes"
  default     = "master"
}

variable "user_policy" {
  default = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": ["*"],
      "Sid": ""
    }
  ]
}
  POLICY
}

variable "activation_id" {
  default = ""
}

variable "customer_id" {
  default = ""
}
