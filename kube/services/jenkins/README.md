# TL;DR

See deploy_jenkins.sh for details on running jenkins on a k8s cluster.

# Some details

The Jenkins deployment includes:

* a jenkins 'service account' - so jenkins can run kubectl commands against the cluster
* AWS secrets, so jenkins can test 'terraform' and back itself up to S3 and whatever.
  You'll have to supply ~/.aws/credentials to deploy_jenkins.sh for a Jenkins IAM
  user with sufficient permissions for Jenkins and terraform to do their thing.
  The following attached policies work in the AWS cdis-test account:
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
* The jenkins-service sets up a public ELB that you can attach a domain name to

Take a look at deploy_jenkins.sh and the different .yaml files under kube/services/jenkins to get all the details.

# Jenkins setup

Once a clean jenkins is setup, then you'll probably want to configure it with Github
OAUTH authentication restricted to a list of specific users, then
setup a Github 'Organization' that automagically launches ./Jenkinsfile pipelines
in branches submitted as pull requests.  Google will give you the details ... :-)