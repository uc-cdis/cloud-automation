# TL;DR

Deploy a cognito user pool given certain information


## 1. QuickStart

```bash
gen3 workon <profile> <name>__cognito
```

Ex:

```bash
$ gen3 workon cdistest generic__cognito
```

## 2. Table of content

- [1. QuickStart](#1-quickstart)
- [2. Table of Contents](#2-table-of-contents)
- [3. Overview](#3-overview)
- [4. Variables](#4-variables)
  - [4.1 Required Variables](#41-required-variables)
  - [4.2 Optional Variables](#42-optional-variables)
- [5. Outputs](#5-outputs)
- [6. Considerations](#6-considerations)



## 3. Overview

Once you workon the workspace, you may want to edit the config.tfvars accordingly.

There are mandatory variables, and there are a few other optionals that are set by default in the variables.tf file, but you can change them if they need to be changed.

Ex.
```bash
vpc_name                 = "generic"
cognito_provider_name    = "microsoftserver.domain.tld"
cognito_domain_name      = "generic-test"
cognito_callback_urls    = ["https://generic.planx-pla.net/","https://generic.planx-pla.net/login/cognito/login/","https://generic.planx-pla.net/user/login/cognito/login/"]
cognito_provider_details = {"MetadataURL"="https://microsoftserver.domain.tld/federationmetadata/2007-06/federationmetadata.xml"}
```

## 4. Variables

### 4.1 Required Variables

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| cognito_provider_details | Details about the auth provider, for this module most likely the MetadataURL or MetadataFILE. | map | {} |
| vpc_name | Name most likely refered to the commons name where the cognito pool will be wired up. | string | |
| cognito_domain_name | The name you want to use a domain prefix, usually will end up something like: https://\<cognito_domain_name\>.auth.us-east-1.amazoncognito.com | string | |
| cognito_callback_urls | Callback URLs that you will include in your sign in requests. | list | |
| cognito_provider_name | Name for the provider. | string | |


### 4.2 Optional Variables

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| cognito_oauth_flows | Allowed OAuth Flows. | list | ["code", "implicit"] |
| cognito_user_pool_name | App client name. | string | "fence" |
| cognito_provider_type | Provider type. | string | "SAML" |
| cognito_attribute_mapping | Federation attribute mapping. | map | { "email" = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress" } |
| cognito_oauth_scopes | Allowed OAuth Scopes. | list | ["email", "openid"] |


## 5. Outputs

| Name | Description | 
|------|-------------|
| cognito_user_pool_id | ID of the cognito user pool. |
| cognito_domain | Same as what was used in the `cognito_domain_name` variable. |
| cognito_user_pool_client | Client id for the app |
| cognito_user_pool_client_secret | Secret for the client, used for authentication against the service. |


## 6. Considerations

After the resource is deployed, there are additional steps to be made in order for the integration commons-SAML to work. The SAML side must allow your endpoint to access it.

The `cognito_user_pool_id` and cognito domain (the full domain, not just the prefix), must be configured on the Active Directory for the full intergration. Additionally, the raw output must be completed before handing the information.

For cognito_user_pool, you might want to refer as "relying party trust identifier" and provide it like `urn:amazon:cognito:sp:<congnito_user_pool_id>`, usually will end up like `urn:amazon:cognito:sp:us-east-1_blabla`.

For cognito domain, the output is just a prefix, the full domain usually is like `https://<cognito_domain>.auth.<region>.amazoncognito.com`.


Then you must configure fence on the commons side to play along with cognito:

```yaml
OPENID_CONNECT:
  cognito:
    # You must create a user pool in order to have a discovery url
    discovery_url: 'https://cognito-idp.us-east-1.amazonaws.com/<cognito_user_pool_id>/.well-known/openid-configuration'
    client_id: '<cognito_user_pool_client>'
    client_secret: '<cognito_user_pool_client_secret>'
    redirect_url: '{{BASE_URL}}/login/cognito/login/'
    assume_emails_verified: True

LOGIN_OPTIONS:
  - name: 'Login from Cognito'
    desc: 'Amazon Cognito login'
    idp: cognito
```


