# TL;DR

See kube-setup-jenkins.sh for details on running jenkins on a k8s cluster.

# Some details

The Jenkins deployment includes:

* a jenkins 'service account' - so jenkins can run kubectl commands against the cluster
* AWS secrets, so jenkins can test 'terraform' and back itself up to S3 and whatever.
  You'll have to supply ~/.aws/credentials to kube-setup-jenkins.sh for a Jenkins IAM
  user with sufficient permissions for Jenkins and terraform to do their thing.
  The following attached policies work in the AWS cdistest account:
    * AmazonRDSFullAccess
    * AmazonEC2FullAccess
    * IAMFullAccess
    * AmazonEC2ContainerRegistryFullAccess
    * AmazonS3FullAccess
    * CdisKmsSuper - AKA kms:* on *
    * AmazonVPCFullAccess
    * AWSKeyManagementServicePowerUser
    * AmazonRoute53FullAccess
    * AWSCertificateManagerFullAccess
* A persistent volume - so jenkins state persists between deployments
  Note that cloud_automation/Jenkins/Pipelines/Backup defines a jenkins
  pipeline that will backup the jenkins filesystem database to S3 if
  properly configured
* The jenkins-service sets up a public ELB that you can attach a domain name to.

The `kube-setup-jenkins.sh` script will hopefully setup everything.
Take a look at `kube-setup-jenkins.sh` and the different .yaml files under kube/services/jenkins to get all the details.
Note that the `apply_service.sh` script deploys the service to kubernetes with the same
SSL cert used by the revproxy ELB (kube-setup-jenkins.sh also deploys the service).

# Jenkins setup

Once a clean jenkins is setup, then you'll probably want to configure it with Github
OAUTH authentication restricted to a list of specific users, then
setup a Github 'Organization' that automagically launches ./Jenkinsfile pipelines
in branches submitted as pull requests.  Google will give you the details ... :-)
