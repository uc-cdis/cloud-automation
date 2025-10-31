# Commons build up steps 

The following guide is intended to guide you through the process of bringing up a gen3 commons. 



# Table of contents


- [1. Requirements](#requirements)
- [2. Setting up the adminVM](#first-part-setting-up-the-adminvm)
- [3. Start gen3](#second-part-start-gen3)
- [4. Deploy kubernetes](#third-part-deploy-the-kubernetes-cluster)
- [5. Bring up services in kubernetes](#fourth-part-bring-up-services-in-kubernetes)




## Requirements

To get started, you must have an AWS account ready in which you will deploy all the resources required to build up a commons.


## 1. Deploying an adminVM

If you are deploying a new cluster on an existing adminVM, then skip this step.

```bash
$ ssh csoc
ubuntu@csoc_admin:~$ gen3 workon csoc account-alias_utilityvm
gen3/account-alias_utilityvm:ubuntu@csoc_admin:~$ gen3 cd
```

Once in the directory, open the config.tfvars file to add the pertinent information regarding your new adminVM

It should look something like:

```bash
bootstrap_path = "cloud-automation/flavors/adminvm/"
bootstrap_script = "init.sh"
vm_name = "account-alias_admin"
vm_hostname = "account-alias_admin"
vpc_cidr_list = ["10.128.0.0/20", "52.0.0.0/8", "54.0.0.0/8", "172.26.224.0/20"]
aws_account_id = "xxxxxxxxxx"
extra_vars = ["account_id=xxxxxxx"]
environment = "environnment-name"
ssh_key_name = "key"
```

Where the `vpc_cidr_list` should mention the CSOC cidr (10.128.0.0/20) and the commons vpc cidr (In this particular example 172.266.224.0/20).

The `environment` variable is for tagging purposes.

`ssh_key_name` wmust be an existing key in the CSOC account.


If done with the variables, then `tfplan/tfapply`

```bash
gen3/account-alias_admin_utilityvm:ubuntu@csoc_admin:~/.local/share/gen3/csoc/account-alias_admin_utilityvm$ gen3 tfplan
gen3/account-alias_admin_utilityvm:ubuntu@csoc_admin:~/.local/share/gen3/csoc/account-alias_admin_utilityvm$ gen3 tfapply
.
.
.
Apply complete! Resources: 8 added, 0 changed, 0 destroyed.

Outputs:

role_id = account-alias_admin_role
utility_private_ip = 10.128.2.42
```

<strong>NOTE:</strong> It is important that you document this information, the new adminVM information must be placed somewhere all DevOps have access and also other PlanX people. 

Please take the time to update [AWS-Accounts.md](https://github.com/uc-cdis/cdis-wiki/blob/master/ops/AWS-Accounts.md)

Also perhaps updating the [spreadsheet](https://docs.google.com/spreadsheets/d/12qmBUZWnlZejJhnzXSqPmRQ-vCs7nFW6K6dcUWqiowo/edit#gid=0) would be ideal.


### Create the logging stream in the CSOC account

In order to store logs for long terms, and into ElasticSearch for short team visibility, we have to deploy a few resources in CSOC

While still in the CSOC master adminVM do tthe following:

```bash
ubuntu@csoc_admin:~$ gen3 workon csoc commons-name_logging
ubuntu@csoc_admin:~$ gen3 cd
```

```bash
child_account_id="199578515826"
common_name="commons-name"
```

Edit the `config.tfvars` accordingly. Then `tfplan/tfapply`


```bash
gen3/commons-name_logging:ubuntu@csoc_admin:~/.local/share/gen3/csoc/commons-name_logging$ gen3 tfplan
gen3/commons-name_logging:ubuntu@csoc_admin:~/.local/share/gen3/csoc/commons-name_logging$ gen3 tfapply
.
.
.
Apply complete! Resources: 18 added, 0 changed, 0 destroyed.

Outputs:

cloudwatch_log_group = commons-name
log_destination = commons-name_logs_destination
s3_bucket = commons-name-logging
```


### Configuring the adminVM

After the adminVM is deployed through the steps above, you may wan to configure it so you can start deploying commons resources. SSH into the adminVM and start the configuration.


1. Clone the repo if it hasn't been already done by the adminVM boootstrap.
```bash
$ git clone https://github.com/uc-cdis/cloud-automation.git
```

2. Install dependencies; you must run this part as a sudo access user. Most likely the bootstrap script took care already, but just in case/
```bash 
bash cloud-automation/gen3/bin/kube-setup-workvm.sh
```


### Configuring the environment


1. Create an user to separate the ubuntu user for general purposes only, usually running the following script would get all the things done:

```bash
#!/bin/bash

if [ -z $1 ];
then    
        echo "Please specify an account"
        exit    
else    
        echo "Creating new user and setting the directory ready for $1"
        ACCOUNT=$1
fi      

sudo useradd -m -s /bin/bash ${ACCOUNT}
sudo cp -rp .aws /home/${ACCOUNT}/
sudo mkdir /home/${ACCOUNT}/.ssh
sudo chmod 700 /home/${ACCOUNT}/.ssh
sudo cp -p .ssh/authorized_keys /home/${ACCOUNT}/.ssh
sudo cp -rp cloud-automation /home/${ACCOUNT} #(or maybe just clone directly there)
sudo chown -R ${ACCOUNT}. /home/${ACCOUNT}

echo "export GEN3_HOME="/home/${ACCOUNT}/cloud-automation"
if [ -f "\${GEN3_HOME}/gen3/gen3setup.sh" ]; then
  source "\${GEN3_HOME}/gen3/gen3setup.sh"
fi" | sudo tee --append /home/${ACCOUNT}/.bashrc
```

2. Switch to the new user

```bash
$ sudo su - newuser
```


3. Edit the local aws config file by adding a profile additionally to the default, even if it's the same info as the default. 
   Usually said file is located in the user's home (${HOME})folder. And it should look something like:
```bash
[default]
output = json
region = us-east-1
role_session_name = gen3-adminvm
role_arn = arn:aws:iam::XXXXXXXXXXXX:role/csoc_adminvm
credential_source = Ec2InstanceMetadata
[profile account-alias]
output = json
region = us-east-1
role_session_name = gen3-adminvm
role_arn = arn:aws:iam::XXXXXXXXXXXX:role/csoc_adminvm
credential_source = Ec2InstanceMetadata
```



## Start gen3

1. Initialize the base module
```bash
gen3 workon <aws profile> <commons-name> 
```

Ex:
```
gen3 workon account-alias commons-test
```

  Note: The third argument of the above command (account-alias) refers to the profile in the config file setup in step above.
        The forth argument (commons-test) would be the name of the commons you want to use; only lowercase letters and hyphens are permitted. Making the commmons-name unique is recommended.

2. Go to the terraform workspace folder
```bash
gen3 cd
```

3. Edit the `config.tfvars` file with your preferred text editor.

  Variables to pay attention to:

`vpc_name` Make sure the vpc_name is unique as some bucket names are derived from the vpc_name.

`vpc_cidr_block` CIDR where the commons resources would reside. EX: 172.16.192.0/20. As for now, only /20 subnets are supported. Your VPC must have only RFC1918 or CG NAT CIDRs.

`dictionary_url` url where the dictionary schema is; it must be in json format.

`portal_app` 

`aws_cert_name` AWS ARN for the certificate to use on the Load Balancer that will be in front. Access to commons is strictly through HTTPS; therefore you need one. You may want request it previously this step.

`hostname` domain which the commons will respond to

`config_folder` folder for permissions. By default, commons would try to load a user.yaml file from s3://cdis-gen3-users/CONFIG_FOLDER/user.yaml. This bucket is not publicly accessible however you can set a different one later. Keep in mind that the folder with the name you are setting this var will need to exist within the bucket and a user.yaml file within the folder in question. You can still set permissions based on a local file. 

`google_client_secret` and `google_client_id`  Google set of API key so you can set google authentication. You can generate a new one through Google Cloud Console.

`deploy_ha_squid` to deploy the commons using ha squid, Boolean.

`deploy_single_proxy` Boolean



4. Create a terraform plan
```bash
gen3 tfplan
```
  You may want to review what will be created by terraform by going through the outputed plan.

5. Apply the previously created plan
```bash
gen3 tfapply
```

When the VPC module is being deployed, it creates a peering connection between account. The approval can't be done automatically, therefore manual intervention is required.

Access the CSOC master admin and rund the following:

```bash
gen3 approve_vpcpeering_request commons-name
```

Because some resources being deployed rely on the peering connection to continue, you may need to run `tfplan/tfapply` again from the the adminVM where the commons is being deployed. Most likely you'll see an error during terraform execuion.


6. Copy the newly commons-test_output folder created to the user's home folder. Keep in mind that you'll see the folder if you haven't `cd` onto a different folder after running `gen3 cd`
```bash
cp -r commons-name_output/ $HOME
```




## Deploy a kubernetes cluster

1. Initialize the EKS module
```bash
gen3 workon account-alias commons-name_eks
```

  Note: The third argument of the above command (account-alias) refers to the profile in the config file setup in step five of the first part.
        The forth argument would be the name of the commons you want to use; only lowercase letters and hyphens are permitted. You must add `_eks` to the name in order to invoke the EKS module.

2. Go to the terraform workspace folder
```bash
gen3 cd
```

3. Edit the `config.tfvars` file with a preferred text editor. 

  Variables to pay attention to:

`vpc_name` name of the commons it *MUST* be the same one used in part two.

`users_policy` this is the name of the policy that allows access to the user.yaml file mentioned in part two. This variable value should always be the same as the above one, but it might differ in very specific cases.

`instance_type` default set to t3.xlarge. Change if necessary.

`ec2_keyname` an existing Key Pair in EC2 for the workers for deployment. More keys can be added automatically if you specify them in $HOME/cloud-automation/files/authorized_keys/ops_team.

**NOTE:** If the following variables are not in the file, just add them along with their values.

`peering_vpc_id` VPC id from where you are running gen3 commands, must be in the same region as where you are running gen3.

`csoc_managed` same as in part 2, if you want it attached to a csoc account. Default is true.

`peering_cidr` basically the CIDR of the VPC where you are running gen3. Pretty much the same as `csoc_vpc_id` for part two.


*Optional*

`eks_version` default set to 1.14, but you can change it to 1.13 or 1.15.


For more information about variables for EKS go to the [EKS Module README](https://github.com/uc-cdis/cloud-automation/blob/master/tf_files/aws/modules/eks/README.md)


4. Create a terraform plan
```bash
gen3 tfplan
```
  You may want to review what will be created by terraform by going through the outputed plan.

5. Apply the previously created plan
```bash
gen3 tfapply
```

6. The EKS module creates a kubernetes configuration file (kubeconfig), copy it to the user's home folder.
```bash
cp commons-test_output_EKS/kubeconfig $HOME
```




## Bring up services in kubernetes

1. Copy the esential files onto `Gen3Secrets` folder
```bash
cd ${HOME}/commons-test_output/
for fileName in 00configmap.yaml creds.json; do
  if [[ -f "${fileName}" && ! -f ~/Gen3Secrets ]]; then
    cp ${fileName} ~/Gen3Secrets/
    mv "${fileName}" "${fileName}.bak"
  else
    echo "Using existing ~/Gen3Secrets/${fileName}"
  fi
done
```

2. Move the kubeconfig file we copied previously into Gen3Secrets.
```bash
mv ${HOME}/kubeconfig ${HOME}/Gen3Secrets/
```

3. Create a manifest folder or clone a repo
```bash
mkdir -p ${HOME}/cdis-manifest/commons-test.planx-pla.net
```

  Note: The cdis-manifest folder is required, if you want to use your own manifest folder name you must make changes to the code, the file containing the line is `cloud-automation/gen3/lib/g3k_manifest.sh`.
        Moreover, a subfolder named the same as your hostname is required.

4. Apply the global manifest
```bash
$ kubectl apply -f ~/Gen3Secrets/00configmap.yaml
```


5. Verify that kubernetes is up. After sourcing our local bashrc file we should be able to talk to kubernetes:
```bash
kubectl get nodes
```

6. Roll services
```bash
gen3 roll all
```
  Note: it might take a few minutes to complete; let it run.

7. Get the newly created ELB endpoint so you can point your domain to it.
```bash
kubectl get service revproxy-service-elb -o json | jq -r .status.loadBalancer.ingress[].hostname
```

8. Go to your registrar and point the desired domain to the outcome of above command.

