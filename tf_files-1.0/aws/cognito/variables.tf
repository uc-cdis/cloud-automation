

variable "cognito_oauth_flows" {
  description = "Allowed OAuth Flows"
  type        = list
  default     = ["code", "implicit"]
}

variable "cognito_user_pool_name" {
  description = "App client"
  default     = "fence"
}

variable "cognito_provider_type" {
  description = "Provider type"
  default     = "SAML"
}

variable "cognito_attribute_mapping" {
  description = "Federation attribute mapping"
  type        = map
  default     = {
    "email" = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
  }
}

variable "cognito_oauth_scopes" {
  description = "Allowed OAuth Scopes"
  type        = list
  default     = ["email", "openid"]
}

variable "cognito_provider_details" {
  description = "The identity provider details"
  type        = map
  default     = {}
}

variable "vpc_name" {
  description = "Commons name in which the cognito user pool will be created"
}

variable "cognito_domain_name" {
  description = "Domain name for the user pool"
}

variable "cognito_callback_urls" {
  description = "Callback URLs below that you will include in your sign in requests"
  type        = list
}

variable "cognito_provider_name" {
  description = "Provider name"
}

variable "tags" {
  description = "Tags for the resource"
  type        = map
  default     = {
    "Organization" = "PlanX"
    "Environment"  = "CSOC"
  }
}
