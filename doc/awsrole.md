# TL;DR
Manage AWS roles for easy use with services

## Use

### list or ls
Lists all roles created with `awsrole`
```
  gen3 awsrole list
```

### create 
Creates a new role if it doesn't already exist
```
  gen3 awsrole create <rolename>
```
Options:
  - rolename: name of role to create

### info
Returns role info
```
   gen3 awsrole info <rolename>
```
Options:
  - rolename: name of role to fetch

### attach-policy
Attaches a policy to a role
```
  gen3 awsrole attach-policy <rolename> <policyARN>
```
Options:
  - rolename: name of role to attach policy to
  - policyARN: arn of policy to attach to role

### create-sa
Create a new service account 
```
  gen3 awsrole create-sa <serviceaccount>
```
Options:
  - serviceaccount: name of service account

### create-assumerole
Create a new role for service account with assumerole policy attached 
```
    gen3 awsrole create-assumerole <serviceaccount>
```
Options:
  - serviceaccount: name of service account
  
### annotate-sa
Annotate service account with Role
```
    gen3 awsrole annotate-sa <serviceaccount> <rolename>
```
Options:
  - serviceaccount: name of service account
  - rolename: name of role 
