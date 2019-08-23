variable "peer1_root_self_link" {
  description = "The ID of the project where this VPC will be created"
}

variable "peer1_add_self_link" {
  description = "The ID of the CSOC project in which the resource belongs."
}

variable "peer1_name" {
  description = "Name of the peer network in commons."
}

variable "peer2_name" {
  description = "Name of the peer network in csoc."
}

variable "peer2_root_self_link" {
  description = "The ID of the project where this VPC will be created"
}

variable "peer2_add_self_link" {
  description = "The ID of the CSOC project in which the resource belongs."
}

variable "auto_create_routes" {
  description = "If set to true, the routes between the two networks will be created and managed automatically. Defaults to true."
  default     = true
}
