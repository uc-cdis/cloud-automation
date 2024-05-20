# Introduction

Karpenter is a modern cloud-native tool for Kubernetes cluster management and resource allocation. With its efficient and customizable scaling and orchestration capabilities, Karpenter is becoming an increasingly popular alternative to Cluster Autoscaler. In this document, we will discuss the benefits of using Karpenter over Cluster Autoscaler and why it is worth considering a switch.

# Table of contents

- [1. Benefits of Karpenter](#benefits-of-karpenter)
- [2. Requirements](#requirements)
- [3. How it Works](#how-it-works)
- [4. Installation Steps](#installation-steps)
- [5. Modifying the Provisioners and Awsnodetemplates](#modifying-the-provisioners-and-awsnodetemplates)
- [6. Potential Issues](#potential-issues)

## Benefits of Karpenter

- Advanced Resource Allocation: Karpenter provides fine-tuned control over resource allocation, allowing for greater optimization of resource utilization. With its advanced features, Karpenter can ensure that nodes are appropriately sized and allocated, reducing the chance of overprovisioning or underutilization.
- Scalability: Karpenter offers powerful scaling capabilities, allowing administrators to quickly and efficiently adjust the size of their cluster as needed. With its sophisticated scaling algorithms, Karpenter ensures that resources are optimized and that clusters are able to grow and shrink as needed.
- Customizable: Karpenter allows administrators to customize and configure their cluster as needed. With its flexible and intuitive interface, administrators can easily adjust the size and composition of their cluster to meet the specific needs of their organization.
- Efficient Management: Karpenter provides efficient and streamlined cluster management, allowing administrators to manage their resources more effectively. With its intuitive and powerful interface, administrators can easily allocate resources and monitor cluster performance, ensuring that their cluster is running smoothly and efficiently.

## Requirements

Karpenter requires access to AWS to be able to provision EC2 instances. It uses an EKS IAM service account with access to most EC2 resources. Once Karpenter is deployed it also requires configuration to decide which node types to spin up, described in the next section. Our base configuration relies on config provisioned using our terraform though, so it may require manual effort to install if not using our terraform. Last, since Karpenter is going to be the new cluster management system, we will need to uninstall the cluster autoscaler. 

## How it Works

Karpenter works on the EKS level instead of the cloud level. This means the systems in place to configure which nodes to spin up are shifted from AWS to EKS configuration. Karpenter uses provisioners to replace autoscaling groups and awsnodetemplates to replace launch configs/templates. Once deployed you will need to create at least one provisioner and one awsnodetemplate so that karpenter can decide what nodes to spin up and once pods require new nodes to spin up karpenter will figure out the most efficient instance type to use based on the pod resources and allowed instance types specified within your provisioner/templates.

## Installation Steps

To install Karpenter using gen3 you can simply run the kube-setup-karpenter script. This script does the following to install karpenter.

1. Creates a new karpenter namespace for the karpenter deployment to run in.
2. Creates an EKS IAM service account with access to EC2 resources within AWS for the Karpenter deployment to use.
3. Tags the relevent subnets and security groups for the karpenter deployment to autodiscover.
4. Installs the karpenter helm deployment
5. Installs the necessary provisioners and aws node templates.

This can also be installed through the manifest by adding a .global.karpenter block to your manifest. If this block equals "arm" then it will also install the arm provisioner, which will provision arm based nodes for the default worker nodes.

## Modifying the Provisioners and Awsnodetemplates

If you ever need to change the behavior of the provisioners on the fly you can run the following command

```bash
kubectl edit provisioners.karpenter.sh
```

If you ever need to edit the awsnodetemplate you can do so with

```bash
kubectl edit awsnodetemplates.karpenter.k8s.aws
```

Base configuration lives in the [karpenter configration section](https://github.com/uc-cdis/cloud-automation/tree/master/kube/services/karpenter) of cloud-automation so you can edit this configuration for longer term or more widespread changes.

## Potential Issues

Karpenter is a powerful flexible tool, but with that can come some challenges. The first is Karpenter needs to be able to find subnets/security groups for your specific VPC. If there are multiple VPC's in an AWS account and multiple Karpenter deployments, we need to stray from the official Karpenter documentation when tagging subnets/security groups. Karpenter will find subnets/security groups tagged a certain way, so instead of setting the tag to be true for karpenter discovery we should set the value to be the VPC name, and similarly set it to be the VPC name within the karpenter configuration. Also, karpenter requires at least 2 nodes outside of any nodes it manages for it's deployment to run on. This is so that karpenter is always available and can schedule nodes without taking itself out. Because of this, we recommend running a regular EKS worker ASG with 2 min/max/desired for karpenter to run on. If these nodes ever need to be updated you will need to ensure karpenter comes back up after to ensure your cluster scales as intended.
