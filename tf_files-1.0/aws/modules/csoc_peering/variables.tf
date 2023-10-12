variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = ""
}

variable "route_table_name" {
  description = "Name of the route table to use for the peering connection"
  type        = string
  default     = "eks_private"
}
  
variable "csoc_vpc_id" {
  description = "VPC ID of the peering connection"
  type        = string
  default     = "vpc-e2b51d99"
}

variable "csoc_cidr" {
  description = "CIDR block of the peering connection"
  type        = string
  default     = ""  
}

variable "organization_name" {
  description = "Name of the organization"
  type        = string
  default     = "cdis"
}

variable "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  type        = string
  default     = ""
}

variable "pcx_id" {
  description = "ID of the peering connection"
  type        = string
  default     = ""
}
