# Commons build up steps 

The following guide is intended to guide you through the process of bringing up a gen3 commons. This particular guide is intended for those who would build commons independently from a centralized account. Said account will be called CSOC and is used to control multiple commons and also collect logs from them for later processing. 



# Table of contents


- [1. Requirements](#requirements)
- [2. Setting up the adminVM](#first-part-setting-up-the-adminvm)
- [3. Start gen3](#second-part-start-gen3)
- [4. Deploy kubernetes](#third-part-deploy-the-kubernetes-cluster)
- [5. Bring up services in kubernetes](#fourth-part-bring-up-services-in-kubernetes)
- [6. Cleanup process](#cleanup-process)




## Requirements

To get started, you must have an AWS account ready in which you will deploy all the resources required to build up a commons. Unfortunately, the deployment may not be small enough, at least as for now, to enter into the free tier zone, therefore, costs may be involved if you decide to test this.

On the bright side, because we use terraform to deploy almost all resources, it is realtively easy to tear them all down.

In order to move on, you must have an EC2 instance up with an admin-like role attached to it. It shouldn't matter in which VPC it is or if it's behind a bastion node or not. In case you don't want to give Full admin access to an EC2 instance, then you will minimally need the following:
```
RDS
EC2
VPC
IAM
KMS
Route53
S3
CloudWatch
Lambda
CloudTrail
SNS
SQS
EKS
```

Additionally, we recommend requesting a SSL certificate for the domain you are going to use to access your commons through AWS certificate manager before moving on because you'll need it later.





## First part, setting up the adminVM

1. Clone the repo
```bash
git clone https://github.com/uc-cdis/cloud-automation.git
```

2. If no proxy is needed then 
```bash
export GEN3_NOPROXY='no'
```
   If a proxy is required, then gen3 would assume cloud-proxy.internal.io:3128 is your proxy for http and https. 

3. Install dependencies; you must run this part as a sudo access user.
```bash 
bash cloud-automation/gen3/bin/kube-setup-workvm.sh
```

4. kube-setup-workvm.sh adds a few required configurations to the user's local bashrc file. To be able to use them, we may want to source it, otherwise we'll have to logout and in again.
```bash
source ${HOME}/.bashrc
```

5. Edit the local aws config file by adding a profile additionally to the default, even if it's the same info as the default. 
   Usually said file is located in the user's home (${HOME})folder. And it should look something like:
```bash
  ubuntu@ip-172-31-40-144:~$ cat ${HOME}/.aws/config 
  [default]
  output = json
  region = us-east-1
  credential_source = Ec2InstanceMetadata

  [profile cdistest]
  output = json
  region = us-east-1
  credential_source = Ec2InstanceMetadata
```

  It's worth noting that additional information may be required in this file but that will depend on your setup for the VM in question.





## Second part start gen3

1. Initialize the base module
```bash
gen3 workon <aws profile> <commons-name> 
```

Ex:
```
gen3 workon cdistest commons-test
```

  Note: The third argument of the above command (cdistest) refers to the profile in the config file setup in step five of the first part.
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


**NOTE:** If the following variables are not in the file, just add them along with their values.

`csoc_managed` if you are going to set up your commons hooked up to a central control management account. By default it is set to true. If you leave the default value, you must run the logging module first, otherwise terraform will fail. But since this instruction is specifically for non-attached deployments, you should set the value to false.

`peering_cidr` this is the CIDR where your adminVM belongs to. Since the commons would create it's own VPC, you need to pair them up to allow communication between them later. Basically, said pairing would let you run kubectl commands against the kubernetes cluster hosting the commons.

`peering_vpc_id` VPC id from where you are running gen3 commands, must be in the same region as where you are running gen3.

`user_bucket_name` This also has something to do with the user.yaml file. In case you need your commons to access a user.yaml file in a different bucket than `cdis-gen3-users`, then add this variable with the corresponding value. Terraform with ultimately create a policy allowing the Kubernetes worker nodes to access the bucket in question (Ex. `s3://<user_bucket_name>/<config_folder>/user.yaml`).

**NOTE:** If you are hooking up your commons with a centralized control management account, you may need to add additional variables to this file with more information about said account.


4. Create a terraform plan
```bash
gen3 tfplan
```
  You may want to review what will be created by terraform by going through the outputed plan.

5. Apply the previously created plan
```bash
gen3 tfapply
```

6. Copy the newly commons-test_output folder created to the user's home folder. Keep in mind that you'll see the folder if you haven't `cd` onto a different folder after running `gen3 cd`
```bash
cp -r commons-test_output/ $HOME
```





## Third part, deploy the kubernetes cluster

1. Initialize the EKS module
```bash
gen3 workon cdistest commons-test_eks
```

  Note: The third argument of the above command (cdistest) refers to the profile in the config file setup in step five of the first part.
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





## Fourth part, bring up services in kubernetes


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

2. Move the kubeconfig file copied previously into Gen3Secrets
```bash
mv ${HOME}/kubeconfig ${HOME}/Gen3Secrets/
```

3. Create a manifest folder
```bash
mkdir -p ${HOME}/cdis-manifest/commons-test.planx-pla.net
```

  Note: The cdis-manifest folder is required, if you want to use your own manifest folder name you must make changes to the code, the file containing the line is `cloud-automation/gen3/lib/g3k_manifest.sh`.
        Moreover, a subfolder named the same as your hostname is required.

4. Create a manifest file

  With the text editor of your preference, create a new file and open it, Ex: `${HOME}/cdis-manifest/commons-test.planx-pla.net/manifest.json`. The content of the file shold be similar to:

```json
{
  "notes": [
    "This is the dev environment manifest",
    "That's all I have to say"
  ],
  "versions": {
    "arborist": "quay.io/cdis/arborist:master",
    "aws-es-proxy": "abutaha/aws-es-proxy:0.8",
    "fence": "quay.io/cdis/fence:master",
    "fluentd": "fluent/fluentd-kubernetes-daemonset:v1.2-debian-cloudwatch",
    "indexd": "quay.io/cdis/indexd:master",
    "jupyterhub": "quay.io/occ_data/jupyterhub:master",
    "peregrine": "quay.io/cdis/peregrine:master",
    "pidgin": "quay.io/cdis/pidgin:master",
    "portal": "quay.io/cdis/data-portal:master",
    "revproxy": "quay.io/cdis/nginx:1.15.5-ctds",
    "sheepdog": "quay.io/cdis/sheepdog:master",
    "spark": "quay.io/cdis/gen3-spark:master",
    "manifestservice": "quay.io/cdis/manifestservice:master",
    "wts": "quay.io/cdis/workspace-token-service:master",
  },
  "arborist": {
    "deployment_version": "2"
  },
  "jupyterhub": {
    "enabled": "no"
  },
  "global": {
    "environment": "devplanetv1",
    "hostname": "commons-test.planx-pla.net",
    "revproxy_arn": "arn:aws:acm:us-east-1:707767160287:certificate/c676c81c-9546-4e9a-9a72-725dd3912bc8",
    "dictionary_url": "https://s3.amazonaws.com/dictionary-artifacts/datadictionary/develop/schema.json",
    "portal_app": "dev",
    "kube_bucket": "kube-commons-test-gen3",
    "logs_bucket": "logs-commons-test-gen3",
    "sync_from_dbgap": "False",
    "useryaml_s3path": "s3://cdis-gen3-users/dev/user.yaml",
    "netpolicy": "on"
  },
  "canary": {
    "default": 0
  }
}
```


5. Check your `.bashrc` file to make sure it'll make gen3 work properly and source it.

The file should look something like the following at the bottom of it:
```bash
export vpc_name='commons-test'
export s3_bucket='kube-commons-test-gen3'

export KUBECONFIG=~/Gen3Secrets/kubeconfig
export GEN3_HOME=~/cloud-automation
if [ -f "${GEN3_HOME}/gen3/gen3setup.sh" ]; then
  source "${GEN3_HOME}/gen3/gen3setup.sh"
fi
alias kubectl=g3kubectl
export GEN3_NOPROXY='no'
if [[ -z "$GEN3_NOPROXY" ]]; then
  export http_proxy='http://cloud-proxy.internal.io:3128'
  export https_proxy='http://cloud-proxy.internal.io:3128'
  export no_proxy='localhost,127.0.0.1,169.254.169.254,.internal.io,logs.us-east-1.amazonaws.com,kibana.planx-pla.net'
fi
```

If it doesn't, adjust accordingly. If it does, source it:
```bash
source ~/.bashrrc
```


6. Verify that kubernetes is up. After sourcing our local bashrc file we should be able to talk to kubernetes:
```bash
kubectl get nodes
```

7. Roll services
```bash
gen3 roll all
```
  Note: it might take a few minutes to complete; let it run.


8. Get the newly created ELB endpoint so you can point your domain to it.
```bash
kubectl get service revproxy-service-elb -o json | jq -r .status.loadBalancer.ingress[].hostname
```

9. Go to your registrar and point the desired domain to the outcome of above command.




# Cleanup process

Clean up is relatively easy. Because we use terraform to build up the infrastructure, we'll also use it to destroy them all.

**NOTE:** Databases have a destroy prevention flag to avoid accidental deletion, therefore if you are deliverately deleting your commons, you may need to skip the flag.

Run the following to remove the protection:

```bash
sed -i 's/prevent_destroy/#prevent_destroy/g' $HOME/cloud-automation/tf_files/aws/commons/kube.tf
```


## Destroying the kubernetes cluster

First you need to delete any resource that was not created by terraform. It will most likely be an Elastic Load balancer that was created when you ran `gen3 roll all`. 


You can view if you have a reverse proxy attached to an ELB through the following command:

```bash
kubectl get service revproxy-service-elb
```

To delete it, run the following:

```bash
kubectl delete service revproxy-service-elb
```

Now, let's delete kubernetes cluster:


```bash
gen3 workon cdistest commons-test_eks
gen3 tfplan --destroy
gen3 tfapply
```


Once that destroy is done, let's delete the base components.

## Destroy the base components


```bash
gen3 workon cdistest commons-test
gen3 tfplan --destroy
gen3 tfapply
```

**NOTES:**
Sometimes buckets created through `gen3` get populated with logs and other data. You may need to empty them before running the above commands. Otherwise, when applying the plan it might fail to delete the bucket.

