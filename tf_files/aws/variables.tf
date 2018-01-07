variable "vpc_name" {
    default = "Commons1"
}
variable "vpc_octet" {
    default = 16
}
variable "aws_region" {
    default = "us-east-1"
}
variable "aws_access_key" {
}
variable "aws_secret_key" {
}
variable "aws_cert_name" {
}
variable "db_size"{
    default = 10
}
variable "db_password_fence" {
    default = ""
}
variable "db_password_userapi" {
    default = ""
}
variable "db_password_gdcapi" {
}
variable "db_password_peregrine" {
}
variable "db_password_sheepdog" {
}
variable "db_password_indexd" {
}
variable "fence_snapshot" {
    default = ""
}
variable "gdcapi_snapshot" {
    default = ""
}
variable "peregrine_snapshot" {
    default = ""
}
variable "sheepdog_snapshot" {
    default = ""
}
variable "indexd_snapshot" {
    default = ""
}
variable "db_instance" {
    default = "db.t2.micro"
}
variable "hostname" {
    default= "dev.bionimbus.org"
}
variable "kube_ssh_key" {
}
/* A list of ssh keys that will be added to
   kubernete nodes, Example:
   '- ssh-rsa XXXX\n - ssh-rsa XXX' */
variable "kube_additional_keys" {
    default = ""
}
variable "kube_bucket" {
    default = "kube_bucket"
}
variable "google_client_id" {
}
variable "google_client_secret" {
}
# 32 alphanumeric characters
variable "hmac_encryption_key" {
}

variable "gdcapi_secret_key" {
}

# password for write access to indexd
variable "gdcapi_indexd_password" {
}
# gdcapi's oauth2 client id(fence as oauth2 provider)
variable "gdcapi_oauth2_client_id" {
}
# gdcapi's oauth2 client secret
variable "gdcapi_oauth2_client_secret" {
}
# id of AWS account that owns the public AMI's
variable "ami_account_id" {
    default = "707767160287"
}
