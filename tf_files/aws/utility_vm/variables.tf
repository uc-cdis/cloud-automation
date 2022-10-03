# id of AWS account that owns the public AMI's
variable "ami_account_id" {
  # by default lets use canonical stuff only
  default = "099720109477"
}

variable "aws_account_id" {
  default = "433568766270"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "vpc_id" {
  default = "vpc-e2b51d99"
}

variable "vpc_subnet_id" {
  default = "subnet-6127013c"
}

variable "vpc_cidr_list" {
  type = list
  default = ["10.128.0.0/20", "54.0.0.0/8", "52.0.0.0/8"]
}

# name of aws_key_pair ssh key to attach to VM's
variable "ssh_key_name" {
}

variable "environment" {
  default = "CSOC"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "image_name_search_criteria" {
  default = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-2022*"
}

variable "extra_vars" {
  type = list
  #default = ["hostname=stuff","accountid=34534534534"]
}

variable "bootstrap_path" {
  #default = "cloud-automation/flavors/nginx/"
}

variable "bootstrap_script" {
  #default = "es_revproxy.sh"
}

variable "vm_name" {
  #default = "nginx_server"
}

variable "vm_hostname" {
  #default = "csoc_nginx_server"
}

variable "proxy" {
  default = true
}

variable "authorized_keys" {
  default = "files/authorized_keys/ops_team"
}

variable "organization_name" {
  description = "For tagging purposes"
  default     = "Basic Service"
}

variable "branch" {
  default = "master"
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
