# Commons build up steps 

The following guide is intended to guide you through the process of adding a secondary CIDR range for workflow nodes 



# Table of contents


- [1. Requirements](#requirements)
- [2. Running the terraform ](#running-the-terraform)
- [3. Manual Steps](#manual-steps)
- [4. Notes](#notes)
- [5. Updating or Deleting the Secondary CIDR](#updating-or-deleting-a-secondary-cidr)

## Requirements

To get started, you need to have a CIDR range that will not overlap with any currently connected CIDR ranges. We would recommend a /16 CIDR range, as workflows can easily spin up tens to hundreds of nodes that will eat through IP's quickly. We normally use 172. addresses, so another thing to keep in mind is not to use 172.17.0.0/16, as that range is reserved for docker, and will create connectivity issues because of the IP overlap. You will also need cloud-automation setup and configured.

## Running the Terraform

Once you have everything you need, you will need to work on your vpc module. From there run a gen3 cd to move to the workspace folder. You will need to add the secondary_cidr_block variable and set the value to your new CIDR range. Once added, run gen3 tfplan then gen3 tfapply to attach the new CIDR range to your vpc. Once that is done you will need to work on the EKS terraform module and do the same.

## Manual Steps

After this is done, if you are running a CSOC setup you will need to make some manual changes. Basically, because we added a new CIDR range we will need to add this range to the adminvm security group in the CSOC, so that you can hit the nodes from the adminvm, and you will need to add it to the main vpc and qualys route tables, so that logging to CSOC and security scans can work.

## Notes

One thing to be aware of is the secondary subnet will need to be added to the cidr proxy list in the EKS control plane. While it is not added some connectivity, such as access to logs through kubectl commands, will be broken. The update is done by EKS and there is no way to manually trigger it besides making an update to EKS that would trigger a reboot, such as an upgrade. However, there is supposed to be a cronjob that runs every 4 hours, so be patient, and the functionality should return within a few hours.

## Updating or Deleting a Secondary CIDR

If you want to update or delete a secondary CIDR, you will need to work on the EKS module first to remove the secondary CIDR, you may also need to scale down the workflow ASG to ensure it can be deleted. Once terraform has removed the resources, you can do the same for the VPC module. Once that is completed, if you want to associate a different secondary CIDR you can by following the process from the start.
