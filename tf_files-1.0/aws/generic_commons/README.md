# Creating Infrastructure with Terraform and Integrating with Helm

This documentation guide will walk you through the process of setting up the required infrastructure on AWS using Terraform. It covers creating an AWS VPC, EKS cluster, Elasticsearch cluster, and RDS cluster. After setting up the infrastructure, we'll integrate it into a Helm deployment for application deployment.

## Prerequisites

Before proceeding, ensure that you have the following prerequisites in place:

1. AWS account credentials (access key and secret key) with necessary permissions to create resources.
2. Terraform installed on your local machine. You can download it from the official Terraform website (<https://www.terraform.io/downloads.html>). Note the modules have been written for terraform version 1.2.
3. Helm installed on your local machine. Refer to the Helm official documentation for installation instructions (<https://helm.sh/docs/intro/install/>).

### Step 1: Download and Configure Terraform Module

1. Git clone the repo.

2. Change directories to the generic commons module.

3. Create a config.tfvars files that has the necessary configuration.

4. No variables are required for the infrastructure setup, but the helm deployment can be configured through terraform variables.

### Step 2: Initialize and Apply Terraform

1. Open a terminal or command prompt and navigate to the module directory.

2. Run the following command to initialize the Terraform workspace:

   ```shell
   terraform init
   ```

3. Once the initialization is complete, execute the following command to create the infrastructure:

   ```shell
   terraform apply
   ```

   Confirm the action by typing `yes` when prompted. The Terraform module will now provision the AWS VPC, EKS cluster, Elasticsearch cluster, and RDS cluster according to the provided configuration.

4. Wait for Terraform to complete the provisioning process. This may take several minutes or longer, depending on the infrastructure complexity.

### Step 3: Manage the application through helm

1. After terraform is completed you should have a working EKS cluster that you can access locally, as well as gen3 and supplmental helm deployments on that cluster.

2. You can check the status of the deployments

   ```shell
   helm ls -A
   ```

3. There will be a local values.yaml file in the directory you ran helm from and you can use that file to manage the deployment moving forward

   ```shell
   helm upgrade --install <deployment name> gen3/gen3 -f ./values.yaml -n <deployment namespace>
   ```

   You should see version information for both the client and server components.

### Step 4: Deleting the deployment

If and when you would like to delete the deployment you can do so with terraform.

1. delete the terraform deployment

```shell
terraform apply --destroy
```

* NOTE: Karpenter may have created nodes that are managed outside of terraform. To ensure these nodes are deleted and the VPC/resources can be reclaimed you can either delete all deployments in the cluster(other than karpenter) and wait for the nodes to be reclaimed, or you can manually terminate the EC2 instances in AWS after the karpenter deployment is removed.
