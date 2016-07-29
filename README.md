# aws-terraform
store terraform configuration files for bringing up VPCs

## Bring up environment using terraform
In order to use terraform first you need to download the [binary](https://www.terraform.io/downloads.html). The credentials are stored in variables.tf, you can export the credential to environment variables. To test how it works, `cd` to `test_tf` folder, then run following to create a vpc.

```
export TF_VAR_aws_access_key=$access_key
export TF_VAR_aws_secret_key=$secret_key
/path/to/terraform/binary apply
```

After the vpc is created, you can call
```
/path/to/terraform/binary destroy
```
to destroy the whole stack.


## Working inside VPC
1. Load your ssh key pair in EC2 -> Key Pairs dashboard.
2. "Launch Instance" in EC2 -> Instances
3. Choose an image -> instance type -> configure instance details -> choose "main" vpc, "private" subnet -> select an existing security group -> select "local" security group  -> select your keypair.
4. Ask an administrator to load your keypair to login node.

## Working inside a VM
1. To login to the VM, first ssh onto login node by `ssh [username]@[vpc-login-ip]`, then `ssh ubuntu@[your-vm-private-ip]`.
2. To reach sites outside of VPC, use `cloud-proxy.internal.com:3128` as http/https proxy.

## Administrator
1. create users' account at "security credentials" -> "create new users", after user is created, assign him to 'developers' group.
2. load an user's ssh key to login node: `ssh ubuntu@[vpc-login-ip]`; sudo create-user $username <key.pub
