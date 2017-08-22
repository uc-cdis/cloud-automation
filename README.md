# aws-terraform
store terraform configuration files for bringing up VPCs

## Prerequisites

#### Configure credentials
- [Create a Google project](https://console.developers.google.com/projectcreate?previousPage=%2Fprojectselector%2Fapis%2Fapi%2Fplus.googleapis.com%2Foverview) with the project name you want to use.
- Enable the Google+ API after you create your project, the link above should take you there after project creation.
- Click "Create Credentials" choose the "Google+ API", then choose "Web server" as API from, and choose "User data" as the data being accessed.
- For the "Authorized JavaScript Origins" enter just the hostname like `https://data.examplecommons.org`.
- For the "Authorized redirect URIs" enter `hostname + '/user/login/google/login/'` so for example `https://data.examplecommons.org/user/login/google/login/`.
- Download your credentials with contain the `client_id` and `client_secret`.
- Copy the [variables.template](https://github.com/uc-cdis/cloud-automation/blob/7bfeda73571d2841894470c9fd11027ed8cadd07/tf_files/variables.template) file to somewhere secure and fill it with creds

#### Configure certificate for your domain
For AWS, use the certificate manager to either import the certs or request admin for the domain to allow AWS to generate certs. The domain should match the hostname you configured in Google or the parent domain name.

#### Using the automated scripts
We have two scripts to guide you through the setup process. You will need your AWS credentials, Google project credentials, an idea of what domain you want to use, and a github username to complete the setup process.
```
./pack_and_terraform.bash
```
This script will grab packer, terraform, and clone the images git. It then proceeds to build the AMIs, and complete the terraform procedure.
```
./setup_kube.bash
```
This script uses the completed results of the step above to set up Kubernetes, and the initial data commons services. There is a manual configuration step here with route53 part way through the process.

#### Create customized AMI
You need to build the amis using [images](https://github.com/uc-cdis/images). Make sure that your ssh key is added in [authorized_keys](https://github.com/uc-cdis/images/blob/master/configs/authorized_keys) before you build those amis.
Required images (build them in order):
- images/base_image.json (after finished, fill the [source_ami](https://github.com/uc-cdis/images/blob/master/variables.example.json#L4) withi this ami ID)
- images/client.json
- images/squid_image.json

## Bring up environment using terraform
In order to use terraform first you need to download the [binary](https://www.terraform.io/downloads.html). You should only bring up the stack after you filled all the creds in the previous step.

```
cd tf_files
terraform plan -var-file=$PATH_TO_YOUR_CREDS_FILE
terraform apply -var-file=$PATH_TO_YOUR_CREDS_FILE
```

After the vpc is created, you can call
```
terraform destroy -var-file=$PATH_TO_YOUR_CREDS_FILE
```
to destroy the whole stack.

## Services brought up by terraform
- Login node. This VM opens  port 22 to the world and is the entry point for ssh access to the cloud.
- HTTP/HTTPS proxy node(cloud-proxy.internal.io). This proxies all HTTP/HTTPS traffic for internal VMs.
- Kubernete provisioner VM (kube.internal.io). This is the VM to use [kube-aws](https://github.com/kubernetes-incubator/kube-aws) to setup the kubernete cluster. kube-aws can be run anywhere, but since we want to setup our k8 cluster inside the private subnet, we have to provision it also inside the same subnet. Since terraform doesn't support ssh access through head node, the needed scripts to setup this node are copied to tf_files/${vpc_name}_output directory, and you need to copy the directory to this VM and follow the [instruction](https://github.com/uc-cdis/cloud-automation/blob/master/kube/README.md) to setup this VM.
- API reverse proxy node(revproxy.internal.io). This is the current single reverse proxy VM for Gen 3 stack apis. This should later be migrated to ELB. Since terraform doesn't support ssh access through head node, the needed scripts to setup this node are copied to tf_files/${vpc_name}_output directory, and you need to copy `proxy.conf` and `revproxy-setup.sh` to this VM and run the setup script after the kubernete cluster is up.

## Working inside VPC
1. Load your ssh key pair in EC2 -> Key Pairs dashboard.
2. "Launch Instance" in EC2 -> Instances
3. Choose an image -> instance type -> configure instance details -> choose the vpc that you just provisioned, "private_2" subnet -> select an existing security group -> select "local" security group  -> select your keypair.
4. Ask an administrator to create your user to login node.

## Working inside a VM
1. To login to the VM, first ssh onto login node by `ssh [username]@[vpc-login-ip]`, then `ssh ubuntu@[your-vm-private-ip]`.
2. To reach sites outside of VPC, use `cloud-proxy.internal.io:3128` as http/https proxy.

## Administrator
1. create users' account at "security credentials" -> "create new users", after user is created, assign him to 'developers' group.
2. load an user's ssh key to login node: `ssh ubuntu@[vpc-login-ip]`; sudo create-user $username <key.pub
