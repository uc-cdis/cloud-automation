# TL;DR

Manage AWS roles for easy use with services

## Use

### list or ls

Lists all roles created with `awsrole`
```
  gen3 awsrole list
```

### create 

Creates a new role if it doesn't already exist, and associate it with the given
service account.
```
  gen3 awsrole create <rolename> <saname>
```
Options:
  - rolename: name of role to create
  - saname: name of the service account to create (if necessary), and annotate

### sa-annotate

Annotate a given service account to link it to the given role.
Create the service account if it does not already exist.
This method is also automatically called by `gen3 aws role create ...` (see above).
```
    gen3 awsrole sa-annotate <saname> <rolename>
```

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


### sa-ar-policy $serviceAccountName

Show the assume-role policy to attach to an AWS role to allow
the given service account to assume that role.
Mostly intended for debugging, but can also use to manually
update a role's assume policy.

ex:
```
gen3 awsrole sa-ar-policy $myServiceAccount
```

Note: we must also annotate the service account:
```
$ g3kubectl annotate --overwrite sa my-serviceaccount eks.amazonaws.com/role-arn=$ROLE_ARN
```

