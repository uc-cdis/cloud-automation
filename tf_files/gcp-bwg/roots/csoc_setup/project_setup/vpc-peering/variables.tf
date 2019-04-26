variable "peer1_name" {
  description = "The name of the VPC peering in the commons project."
  
}
variable "peer2_name" {
  description = "The name of the VPC peering in the csoc project."
}
variable "project_id" {
  description = "The globally unique project id for the commons project."
}
variable "csoc_project_id" {
  description = "The globally unique project id for the csoc project."
}

variable "peer1_create_routes" {
  description = "If set to true, the routes between the two networks will be created and managed automatically. Defaults to true."
  default = "true"
}

variable "peer2_create_routes" {
  description = "If set to true, the routes between the two networks will be created and managed automatically. Defaults to true."
  default = "true"
}
