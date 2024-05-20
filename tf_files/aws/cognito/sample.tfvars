
#A list of allowed OAuth Flows
cognito_oauth_flows = ["code", "implicit"]

#A user directory for Amazon Cognito, which handles sign-on for users. This is generally given the same name as the 
#name of the app using the service.
cognito_user_pool_name = "fence"

#The identity provider types that Cognito will use. An identity provider is a service that stores and manages 
#identities. See: https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_CreateIdentityProvider.html#CognitoUserPools-CreateIdentityProvider-request-ProviderType
cognito_provider_type = "SAML"

#The attribute mapping is how Cognito translates the information about a user recieved from an identitiy provider into
#the attributes that Cognito expects from a user. 
#For more information, see: https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-specifying-attribute-mapping.html
cognito_attribute_mapping = {
    "email" = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
  }

#The OAuth scopes specify what information from a user's account Cognito is able to access. Scopes are provider-specific, and
#you will need to consult the documentation for your identity provider to determine what scopes are necessary and valid
cognito_oauth_scopes = ["email", "openid"]

#Details about the auth provider, for this module most likely the MetadataURL or MetadataFILE
cognito_provider_details = {}

#The name of the VPC that the Cognito pool will be created in
vpc_name = ""

#The address of the sign-in and sign-up pages
cognito_domain_name = ""

#The URL(s) that can be redirected to after a successful sign-in
cognito_callback_urls = []

#The name of the provided identity provider. This is the name used within AWS
cognito_provider_name = ""

#A map contaning key-value pairs used in AWS to filter and search for resources
tags = {
    "Organization" = "PlanX"
    "Environment"  = "CSOC"
  }

