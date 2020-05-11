
vpc_name                 = "INSERT VPC NAME HERE"
cognito_provider_name    = "federation name"
cognito_domain_name      = "subname for .auth.us-east-1.amazoncognito.com"
cognito_callback_urls    = ["https://url1"]
cognito_provider_details = {"MetadataURL"="https://someurl"}
tags                     = {
  "Organization" = "PlanX"
  "Environment"  = "CSOC"
}
