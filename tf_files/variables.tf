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
variable "host_name" {
    default= "data.bloodpac.org"
}