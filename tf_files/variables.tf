variable "vpc_name" {
}
variable "aws_access_key" {
}
variable "aws_secret_key" {
}
variable "login_ami" {
}
variable "proxy_ami" {
}
variable "base_ami" {
}
variable "db_size"{
    default = 10
}
variable "db_name" {
}
variable "db_password_userapi" {
}
variable "db_password_gdcapi" {
}
variable "db_password_indexd" {
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
}
variable "google_client_id" {
}
variable "google_client_secret" {
}