variable "project_id" {
  description = "The ID of the project where this VPC will be created"
}

variable "csoc_project_id" {
  description = "The ID of the CSOC project in which the resource belongs."
}

variable "peer1_name" {
  description = "Name of the peer network in commons."
}

variable "peer2_name" {
  description = "Name of the peer network in csoc."
}

variable "peer1_create_routes" {
  description = "If set to true, the routes between the two networks will be created and managed automatically. Defaults to true."
  default     = "true"
}

variable "peer2_create_routes" {
  description = "If set to true, the routes between the two networks will be created and managed automatically. Defaults to true."
  default     = "true"
}
