#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

accountNumber="$(aws sts get-caller-identity --output text --query 'Account')"

gen3_tf_migrate_prep_tfstate() {
  # Workon the old commons module to gather where the tfstate file is located
  gen3 workon $profile $oldWorkspace
  gen3 cd
  config=$(cat config.tfvars)
  tfBucket=$(cat backend.tfvars | grep bucket | cut -d '"' -f 2)
  tfKey=$(cat backend.tfvars | grep key | cut -d '"' -f 2)
  # Workon the old EKS module to gather where the tfstate file is located
  gen3 workon $profile "${oldWorkspace}_eks"
  gen3 cd
  tfBucketEKS=$(cat backend.tfvars | grep bucket | cut -d '"' -f 2)
  tfKeyEKS=$(cat backend.tfvars | grep key | cut -d '"' -f 2)
  # Workon the old ES module to gather where the tfstate file is located
  if [[ $migrateEs ]]; then
    gen3 workon $profile "${oldWorkspace}_es"
    gen3 cd
    tfBucketES=$(cat backend.tfvars | grep bucket | cut -d '"' -f 2)
    tfKeyES=$(cat backend.tfvars | grep key | cut -d '"' -f 2)
  fi
  # Workon the new module to start the migration
  gen3 workon $profile $newWorkspace
  gen3 cd
  # Take a backup just in case we made a mistake and want to keep a tfstate file from improperly being overwritten, should fail otherwise
  aws s3 cp s3://$tfBucket/$newWorkspace/terraform.tfstate ./tfstate-bck
  # Copy down the old tf state files
  aws s3 cp s3://$tfBucket/$tfKey ./terraform.tfstate-commons
  aws s3 cp s3://$tfBucket/$tfKeyEKS ./terraform.tfstate-eks
  aws s3 cp s3://$tfBucket/$tfKeyES ./terraform.tfstate-es
  # Merge the state files
  # Currently need to specify the top level blocks and merge the modules block to work around issues merging json with differing top level values causing arrays to appear where we don't want them
  if [[ $migrateEs ]]; then
    jq -s '{"version": 3, "terraform_version": "0.11.15", "serial": 171, "lineage": "8a7caf05-a6eb-b3af-58cb-6d4bd6e080e7", modules: map(.modules[]) }' terraform.tfstate-eks terraform.tfstate-commons terraform.tfstate-es > tfimport
  else
    jq -s '{"version": 3, "terraform_version": "0.11.15", "serial": 171, "lineage": "8a7caf05-a6eb-b3af-58cb-6d4bd6e080e7", modules: map(.modules[]) }' terraform.tfstate-eks terraform.tfstate-commons > tfimport
  fi
  # Upload the combined tf state files to new workspace s3 location
  aws s3 cp ./tfimport s3://$tfBucket/$newWorkspace/terraform.tfstate
}

gen3_tf_migrate_update_providers() {
  gen3 workon $profile $newWorkspace
  # Newer tf version has new provider locations and we need to replace the providers we used with the new ones
  gen3 tform state replace-provider -auto-approve registry.terraform.io/-/aws registry.terraform.io/hashicorp/aws
  gen3 tform state replace-provider -auto-approve registry.terraform.io/-/archive registry.terraform.io/hashicorp/archive
  gen3 tform state replace-provider -auto-approve registry.terraform.io/-/null registry.terraform.io/hashicorp/null
  gen3 tform state replace-provider -auto-approve registry.terraform.io/-/template registry.terraform.io/hashicorp/template
  gen3 tform state replace-provider -auto-approve registry.terraform.io/-/random registry.terraform.io/hashicorp/random
}

gen3_tf_migrate_move_resources() {
  # Workon the profile again to ensure that the terraform state changes have been pushed up and new providers have been downloaded correctly
  gen3 workon $profile $newWorkspace
  # Remove random shuffle resources because of problems with upgrade
  gen3 tform state rm module.eks.random_shuffle.az module.eks.random_shuffle.secondary_az
  # Move all resources that have changed between versions
  gen3 tform state mv module.cdis_alarms.aws_cloudwatch_metric_alarm.fence_db_alarm module.cdis_alarms[0].aws_cloudwatch_metric_alarm.fence_db_alarm
  gen3 tform state mv module.cdis_alarms.aws_cloudwatch_metric_alarm.gdcapi_db_alarm module.cdis_alarms[0].aws_cloudwatch_metric_alarm.gdcapi_db_alarm
  gen3 tform state mv module.cdis_alarms.aws_cloudwatch_metric_alarm.indexd_db_alarm module.cdis_alarms[0].aws_cloudwatch_metric_alarm.indexd_db_alarm
  gen3 tform state mv module.cdis_alarms.module.alarms-lambda.aws_iam_role.lambda_role module.cdis_alarms[0].module.alarms-lambda.aws_iam_role.lambda_role
  gen3 tform state mv module.cdis_alarms.module.alarms-lambda.aws_iam_role_policy.lambda_policy module.cdis_alarms[0].module.alarms-lambda.aws_iam_role_policy.lambda_policy
  gen3 tform state mv module.cdis_alarms.module.alarms-lambda.aws_lambda_function.lambda module.cdis_alarms[0].module.alarms-lambda.aws_lambda_function.lambda
  gen3 tform state mv module.cdis_alarms.module.alarms-lambda.aws_lambda_permission.with_sns module.cdis_alarms[0].module.alarms-lambda.aws_lambda_permission.with_sns
  gen3 tform state mv module.cdis_alarms.module.alarms-lambda.aws_sns_topic.cloudwatch-alarms module.cdis_alarms[0].module.alarms-lambda.aws_sns_topic.cloudwatch-alarms
  gen3 tform state mv module.cdis_alarms.module.alarms-lambda.aws_sns_topic_subscription.cloudwatch_lambda module.cdis_alarms[0].module.alarms-lambda.aws_sns_topic_subscription.cloudwatch_lambda
  gen3 tform state mv module.cdis_alarms.module.alarms-lambda.data.archive_file.cloudwatch_lambda module.cdis_alarms[0].module.alarms-lambda.data.archive_file.cloudwatch_lambda
  gen3 tform state mv module.cdis_alarms.module.alarms-lambda.data.aws_iam_policy_document.cloudwatch-lambda-policy module.cdis_alarms[0].module.alarms-lambda.data.aws_iam_policy_document.cloudwatch-lambda-policy
  gen3 tform state mv module.eks.aws_autoscaling_group.eks_autoscaling_group module.eks[0].aws_autoscaling_group.eks_autoscaling_group[0]
  gen3 tform state mv module.eks.aws_cloudwatch_event_rule.gw_checks_rule module.eks[0].aws_cloudwatch_event_rule.gw_checks_rule[0]
  gen3 tform state mv module.eks.aws_cloudwatch_event_target.cw_to_lambda module.eks[0].aws_cloudwatch_event_target.cw_to_lambda[0]
  gen3 tform state mv module.eks.aws_cloudwatch_log_group.gwl_group module.eks[0].aws_cloudwatch_log_group.gwl_group[0]
  gen3 tform state mv module.eks.aws_eks_cluster.eks_cluster module.eks[0].aws_eks_cluster.eks_cluster
  gen3 tform state mv module.eks.aws_iam_instance_profile.eks_node_instance_profile module.eks[0].aws_iam_instance_profile.eks_node_instance_profile
  gen3 tform state mv module.eks.aws_iam_openid_connect_provider.identity_provider module.eks[0].aws_iam_openid_connect_provider.identity_provider[0]
  gen3 tform state mv module.eks.aws_iam_policy.asg_access module.eks[0].aws_iam_policy.asg_access
  gen3 tform state mv module.eks.aws_iam_policy.cwl_access_policy module.eks[0].aws_iam_policy.cwl_access_policy
  gen3 tform state mv module.eks.aws_iam_role.eks_control_plane_role module.eks[0].aws_iam_role.eks_control_plane_role
  gen3 tform state mv module.eks.aws_iam_role.eks_node_role module.eks[0].aws_iam_role.eks_node_role
  gen3 tform state mv module.eks.aws_iam_role_policy_attachment.asg_access module.eks[0].aws_iam_role_policy_attachment.asg_access
  gen3 tform state mv module.eks.aws_iam_role_policy_attachment.bucket_read module.eks[0].aws_iam_role_policy_attachment.bucket_read
  gen3 tform state mv module.eks.aws_iam_role_policy_attachment.bucket_write module.eks[0].aws_iam_role_policy_attachment.bucket_write
  gen3 tform state mv module.eks.aws_iam_role_policy_attachment.cloudwatch_logs_access module.eks[0].aws_iam_role_policy_attachment.cloudwatch_logs_access
  gen3 tform state mv module.eks.aws_iam_role_policy_attachment.eks-node-AmazonEC2ContainerRegistryReadOnly module.eks[0].aws_iam_role_policy_attachment.eks-node-AmazonEC2ContainerRegistryReadOnly
  gen3 tform state mv module.eks.aws_iam_role_policy_attachment.eks-node-AmazonEKS_CNI_Policy module.eks[0].aws_iam_role_policy_attachment.eks-node-AmazonEKS_CNI_Policy
  gen3 tform state mv module.eks.aws_iam_role_policy_attachment.eks-node-AmazonEKSWorkerNodePolicy module.eks[0].aws_iam_role_policy_attachment.eks-node-AmazonEKSWorkerNodePolicy
  gen3 tform state mv module.eks.aws_iam_role_policy_attachment.eks-policy-AmazonEKSClusterPolicy module.eks[0].aws_iam_role_policy_attachment.eks-policy-AmazonEKSClusterPolicy
  gen3 tform state mv module.eks.aws_iam_role_policy_attachment.eks-policy-AmazonEKSServicePolicy module.eks[0].aws_iam_role_policy_attachment.eks-policy-AmazonEKSServicePolicy
  gen3 tform state mv module.eks.aws_iam_role_policy_attachment.eks-policy-AmazonSSMManagedInstanceCore module.eks[0].aws_iam_role_policy_attachment.eks-policy-AmazonSSMManagedInstanceCore
  gen3 tform state mv module.eks.aws_iam_role_policy_attachment.lambda_logs module.eks[0].aws_iam_role_policy_attachment.lambda_logs[0]
  gen3 tform state mv module.eks.aws_iam_role_policy.csoc_alert_sns_access module.eks[0].aws_iam_role_policy.csoc_alert_sns_access[0]
  gen3 tform state mv module.eks.aws_iam_role_policy.lambda_policy_no_resources module.eks[0].aws_iam_role_policy.lambda_policy_no_resources[0]
  gen3 tform state mv module.eks.aws_iam_role_policy.lambda_policy_resources module.eks[0].aws_iam_role_policy.lambda_policy_resources[0]
  gen3 tform state mv module.eks.aws_iam_service_linked_role.autoscaling module.eks[0].aws_iam_service_linked_role.autoscaling
  gen3 tform state mv module.eks.aws_lambda_function.gw_checks module.eks[0].aws_lambda_function.gw_checks[0]
  gen3 tform state mv module.eks.aws_lambda_permission.allow_cloudwatch module.eks[0].aws_lambda_permission.allow_cloudwatch[0]
  gen3 tform state mv module.eks.aws_launch_configuration.eks_launch_configuration module.eks[0].aws_launch_configuration.eks_launch_configuration[0]
  gen3 tform state mv module.eks.aws_route.for_peering module.eks[0].aws_route.for_peering
  gen3 tform state mv module.eks.aws_route_table_association.private_kube[0] module.eks[0].aws_route_table_association.private_kube[0]
  gen3 tform state mv module.eks.aws_route_table_association.private_kube[1] module.eks[0].aws_route_table_association.private_kube[1]
  gen3 tform state mv module.eks.aws_route_table_association.private_kube[2] module.eks[0].aws_route_table_association.private_kube[2]
  gen3 tform state mv module.eks.aws_route_table_association.public_kube[0] module.eks[0].aws_route_table_association.public_kube[0]
  gen3 tform state mv module.eks.aws_route_table_association.public_kube[1] module.eks[0].aws_route_table_association.public_kube[1]
  gen3 tform state mv module.eks.aws_route_table_association.public_kube[2] module.eks[0].aws_route_table_association.public_kube[2]
  gen3 tform state mv module.eks.aws_route_table.eks_private module.eks[0].aws_route_table.eks_private
  gen3 tform state mv module.eks.aws_security_group.eks_control_plane_sg module.eks[0].aws_security_group.eks_control_plane_sg
  gen3 tform state mv module.eks.aws_security_group.eks_nodes_sg module.eks[0].aws_security_group.eks_nodes_sg
  gen3 tform state mv module.eks.aws_security_group_rule.communication_plane_to_nodes module.eks[0].aws_security_group_rule.communication_plane_to_nodes
  gen3 tform state mv module.eks.aws_security_group_rule.https_nodes_to_plane module.eks[0].aws_security_group_rule.https_nodes_to_plane
  gen3 tform state mv module.eks.aws_security_group_rule.nodes_internode_communications module.eks[0].aws_security_group_rule.nodes_internode_communications
  gen3 tform state mv module.eks.aws_security_group_rule.nodes_interpool_communications module.eks[0].aws_security_group_rule.nodes_interpool_communications
  gen3 tform state mv module.eks.aws_security_group_rule.workflow_nodes_interpool_communications module.eks[0].aws_security_group_rule.workflow_nodes_interpool_communications[0]
  gen3 tform state mv module.eks.aws_security_group.ssh module.eks[0].aws_security_group.ssh
  gen3 tform state mv module.eks.aws_subnet.eks_private[0] module.eks[0].aws_subnet.eks_private[0]
  gen3 tform state mv module.eks.aws_subnet.eks_private[1] module.eks[0].aws_subnet.eks_private[1]
  gen3 tform state mv module.eks.aws_subnet.eks_private[2] module.eks[0].aws_subnet.eks_private[2]
  gen3 tform state mv module.eks.aws_subnet.eks_public[0] module.eks[0].aws_subnet.eks_public[0]
  gen3 tform state mv module.eks.aws_subnet.eks_public[1] module.eks[0].aws_subnet.eks_public[1]
  gen3 tform state mv module.eks.aws_subnet.eks_public[2] module.eks[0].aws_subnet.eks_public[2]
  gen3 tform state mv module.eks.aws_vpc_endpoint.autoscaling module.eks[0].aws_vpc_endpoint.autoscaling
  gen3 tform state mv module.eks.aws_vpc_endpoint.ebs module.eks[0].aws_vpc_endpoint.ebs
  gen3 tform state mv module.eks.aws_vpc_endpoint.ec2 module.eks[0].aws_vpc_endpoint.ec2
  gen3 tform state mv module.eks.aws_vpc_endpoint.ecr-api module.eks[0].aws_vpc_endpoint.ecr-api
  gen3 tform state mv module.eks.aws_vpc_endpoint.ecr-dkr module.eks[0].aws_vpc_endpoint.ecr-dkr
  gen3 tform state mv module.eks.aws_vpc_endpoint.k8s-logs module.eks[0].aws_vpc_endpoint.k8s-logs
  gen3 tform state mv module.eks.aws_vpc_endpoint.k8s-s3 module.eks[0].aws_vpc_endpoint.k8s-s3
  gen3 tform state mv module.eks.aws_vpc_endpoint.sts module.eks[0].aws_vpc_endpoint.sts
  gen3 tform state mv module.eks.data.archive_file.lambda_function module.eks[0].data.archive_file.lambda_function
  gen3 tform state mv module.eks.data.aws_ami.eks_worker module.eks[0].data.aws_ami.eks_worker
  gen3 tform state mv module.eks.data.aws_autoscaling_group.squid_auto module.eks[0].data.aws_autoscaling_group.squid_auto[0]
  gen3 tform state mv module.eks.data.aws_availability_zones.available module.eks[0].data.aws_availability_zones.available
  gen3 tform state mv module.eks.data.aws_caller_identity.current module.eks[0].data.aws_caller_identity.current
  gen3 tform state mv module.eks.data.aws_iam_policy_document.planx-csoc-alerts-topic_access module.eks[0].data.aws_iam_policy_document.planx-csoc-alerts-topic_access[0]
  gen3 tform state mv module.eks.data.aws_iam_policy_document.without_resources module.eks[0].data.aws_iam_policy_document.without_resources
  gen3 tform state mv module.eks.data.aws_iam_policy_document.with_resources module.eks[0].data.aws_iam_policy_document.with_resources
  gen3 tform state mv module.eks.data.aws_nat_gateway.the_gateway module.eks[0].data.aws_nat_gateway.the_gateway
  gen3 tform state mv module.eks.data.aws_region.current module.eks[0].data.aws_region.current
  gen3 tform state mv module.eks.data.aws_route53_zone.vpczone module.eks[0].data.aws_route53_zone.vpczone
  gen3 tform state mv module.eks.data.aws_route_table.private_kube_route_table module.eks[0].data.aws_route_table.private_kube_route_table
  gen3 tform state mv module.eks.data.aws_route_table.public_kube module.eks[0].data.aws_route_table.public_kube
  gen3 tform state mv module.eks.data.aws_security_group.local_traffic module.eks[0].data.aws_security_group.local_traffic
  gen3 tform state mv module.eks.data.aws_vpc_endpoint_service.autoscaling module.eks[0].data.aws_vpc_endpoint_service.autoscaling
  gen3 tform state mv module.eks.data.aws_vpc_endpoint_service.ebs module.eks[0].data.aws_vpc_endpoint_service.ebs
  gen3 tform state mv module.eks.data.aws_vpc_endpoint_service.ec2 module.eks[0].data.aws_vpc_endpoint_service.ec2
  gen3 tform state mv module.eks.data.aws_vpc_endpoint_service.ecr_api module.eks[0].data.aws_vpc_endpoint_service.ecr_api
  gen3 tform state mv module.eks.data.aws_vpc_endpoint_service.ecr_dkr module.eks[0].data.aws_vpc_endpoint_service.ecr_dkr
  gen3 tform state mv module.eks.data.aws_vpc_endpoint_service.logs module.eks[0].data.aws_vpc_endpoint_service.logs
  gen3 tform state mv module.eks.data.aws_vpc_endpoint_service.sts module.eks[0].data.aws_vpc_endpoint_service.sts
  gen3 tform state mv module.eks.data.aws_vpc_peering_connection.pc module.eks[0].data.aws_vpc_peering_connection.pc
  gen3 tform state mv module.eks.data.aws_vpcs.vpcs module.eks[0].data.aws_vpcs.vpcs
  gen3 tform state mv module.eks.data.aws_vpc.the_vpc module.eks[0].data.aws_vpc.the_vpc
  gen3 tform state mv module.eks.data.template_file.bootstrap module.eks[0].data.template_file.bootstrap
  gen3 tform state mv module.eks.data.template_file.init_cluster module.eks[0].data.template_file.init_cluster
  gen3 tform state mv module.eks.data.template_file.kube_config module.eks[0].data.template_file.kube_config
  gen3 tform state mv module.eks.data.template_file.ssh_keys module.eks[0].data.template_file.ssh_keys
  gen3 tform state mv module.eks.module.iam_policy.aws_iam_policy.policy module.eks[0].module.iam_policy[0].aws_iam_policy.policy
  gen3 tform state mv module.eks.module.iam_role.aws_iam_role.the_role module.eks[0].module.iam_role[0].aws_iam_role.the_role
  gen3 tform state mv module.eks.module.jupyter_pool.aws_autoscaling_group.eks_autoscaling_group module.eks[0].module.jupyter_pool[0].aws_autoscaling_group.eks_autoscaling_group
  gen3 tform state mv module.eks.module.jupyter_pool.aws_iam_instance_profile.eks_node_instance_profile module.eks[0].module.jupyter_pool[0].aws_iam_instance_profile.eks_node_instance_profile
  gen3 tform state mv module.eks.module.jupyter_pool.aws_iam_policy.access_to_kernels module.eks[0].module.jupyter_pool[0].aws_iam_policy.access_to_kernels
  gen3 tform state mv module.eks.module.jupyter_pool.aws_iam_policy.asg_access module.eks[0].module.jupyter_pool[0].aws_iam_policy.asg_access
  gen3 tform state mv module.eks.module.jupyter_pool.aws_iam_policy.cwl_access_policy module.eks[0].module.jupyter_pool[0].aws_iam_policy.cwl_access_policy
  gen3 tform state mv module.eks.module.jupyter_pool.aws_iam_role.eks_control_plane_role module.eks[0].module.jupyter_pool[0].aws_iam_role.eks_control_plane_role
  gen3 tform state mv module.eks.module.jupyter_pool.aws_iam_role.eks_node_role module.eks[0].module.jupyter_pool[0].aws_iam_role.eks_node_role
  gen3 tform state mv module.eks.module.jupyter_pool.aws_iam_role_policy_attachment.asg_access module.eks[0].module.jupyter_pool[0].aws_iam_role_policy_attachment.asg_access
  gen3 tform state mv module.eks.module.jupyter_pool.aws_iam_role_policy_attachment.bucket_write module.eks[0].module.jupyter_pool[0].aws_iam_role_policy_attachment.bucket_write
  gen3 tform state mv module.eks.module.jupyter_pool.aws_iam_role_policy_attachment.cloudwatch_logs_access module.eks[0].module.jupyter_pool[0].aws_iam_role_policy_attachment.cloudwatch_logs_access
  gen3 tform state mv module.eks.module.jupyter_pool.aws_iam_role_policy_attachment.eks-node-AmazonEC2ContainerRegistryReadOnly module.eks[0].module.jupyter_pool[0].aws_iam_role_policy_attachment.eks-node-AmazonEC2ContainerRegistryReadOnly
  gen3 tform state mv module.eks.module.jupyter_pool.aws_iam_role_policy_attachment.eks-node-AmazonEKS_CNI_Policy module.eks[0].module.jupyter_pool[0].aws_iam_role_policy_attachment.eks-node-AmazonEKS_CNI_Policy
  gen3 tform state mv module.eks.module.jupyter_pool.aws_iam_role_policy_attachment.eks-node-AmazonEKSWorkerNodePolicy module.eks[0].module.jupyter_pool[0].aws_iam_role_policy_attachment.eks-node-AmazonEKSWorkerNodePolicy
  gen3 tform state mv module.eks.module.jupyter_pool.aws_iam_role_policy_attachment.eks-policy-AmazonEKSClusterPolicy module.eks[0].module.jupyter_pool[0].aws_iam_role_policy_attachment.eks-policy-AmazonEKSClusterPolicy
  gen3 tform state mv module.eks.module.jupyter_pool.aws_iam_role_policy_attachment.eks-policy-AmazonEKSServicePolicy module.eks[0].module.jupyter_pool[0].aws_iam_role_policy_attachment.eks-policy-AmazonEKSServicePolicy
  gen3 tform state mv module.eks.module.jupyter_pool.aws_iam_role_policy_attachment.eks-policy-AmazonSSMManagedInstanceCore module.eks[0].module.jupyter_pool[0].aws_iam_role_policy_attachment.eks-policy-AmazonSSMManagedInstanceCore
  gen3 tform state mv module.eks.module.jupyter_pool.aws_iam_role_policy_attachment.kernel_access module.eks[0].module.jupyter_pool[0].aws_iam_role_policy_attachment.kernel_access
  gen3 tform state mv module.eks.module.jupyter_pool.aws_launch_configuration.eks_launch_configuration module.eks[0].module.jupyter_pool[0].aws_launch_configuration.eks_launch_configuration
  gen3 tform state mv module.eks.module.jupyter_pool.aws_security_group.eks_nodes_sg module.eks[0].module.jupyter_pool[0].aws_security_group.eks_nodes_sg
  gen3 tform state mv module.eks.module.jupyter_pool.aws_security_group_rule.communication_plane_to_nodes module.eks[0].module.jupyter_pool[0].aws_security_group_rule.communication_plane_to_nodes
  gen3 tform state mv module.eks.module.jupyter_pool.aws_security_group_rule.https_nodes_to_plane module.eks[0].module.jupyter_pool[0].aws_security_group_rule.https_nodes_to_plane
  gen3 tform state mv module.eks.module.jupyter_pool.aws_security_group_rule.nodes_internode_communications module.eks[0].module.jupyter_pool[0].aws_security_group_rule.nodes_internode_communications
  gen3 tform state mv module.eks.module.jupyter_pool.aws_security_group_rule.nodes_interpool_communications module.eks[0].module.jupyter_pool[0].aws_security_group_rule.nodes_interpool_communications
  gen3 tform state mv module.eks.module.jupyter_pool.aws_security_group.ssh module.eks[0].module.jupyter_pool[0].aws_security_group.ssh
  gen3 tform state mv module.eks.module.jupyter_pool.data.aws_ami.eks_worker module.eks[0].module.jupyter_pool[0].data.aws_ami.eks_worker
  gen3 tform state mv module.eks.module.jupyter_pool.data.aws_availability_zones.available module.eks[0].module.jupyter_pool[0].data.aws_availability_zones.available
  gen3 tform state mv module.eks.module.jupyter_pool.data.aws_caller_identity.current module.eks[0].module.jupyter_pool[0].data.aws_caller_identity.current
  gen3 tform state mv module.eks.module.jupyter_pool.data.aws_region.current module.eks[0].module.jupyter_pool[0].data.aws_region.current
  gen3 tform state mv module.eks.module.jupyter_pool.data.aws_vpcs.vpcs module.eks[0].module.jupyter_pool[0].data.aws_vpcs.vpcs
  gen3 tform state mv module.eks.module.jupyter_pool.data.aws_vpc.the_vpc module.eks[0].module.jupyter_pool[0].data.aws_vpc.the_vpc
  gen3 tform state mv module.eks.module.jupyter_pool.data.template_file.bootstrap module.eks[0].module.jupyter_pool[0].data.template_file.bootstrap
  gen3 tform state mv module.eks.module.jupyter_pool.data.template_file.ssh_keys module.eks[0].module.jupyter_pool[0].data.template_file.ssh_keys
  gen3 tform state mv module.eks.module.workflow_pool.aws_autoscaling_group.eks_autoscaling_group module.eks[0].module.workflow_pool[0].aws_autoscaling_group.eks_autoscaling_group
  gen3 tform state mv module.eks.module.workflow_pool.aws_iam_instance_profile.eks_node_instance_profile module.eks[0].module.workflow_pool[0].aws_iam_instance_profile.eks_node_instance_profile
  gen3 tform state mv module.eks.module.workflow_pool.aws_iam_policy.access_to_kernels module.eks[0].module.workflow_pool[0].aws_iam_policy.access_to_kernels
  gen3 tform state mv module.eks.module.workflow_pool.aws_iam_policy.asg_access module.eks[0].module.workflow_pool[0].aws_iam_policy.asg_access
  gen3 tform state mv module.eks.module.workflow_pool.aws_iam_policy.cwl_access_policy module.eks[0].module.workflow_pool[0].aws_iam_policy.cwl_access_policy
  gen3 tform state mv module.eks.module.workflow_pool.aws_iam_role.eks_control_plane_role module.eks[0].module.workflow_pool[0].aws_iam_role.eks_control_plane_role
  gen3 tform state mv module.eks.module.workflow_pool.aws_iam_role.eks_node_role module.eks[0].module.workflow_pool[0].aws_iam_role.eks_node_role
  gen3 tform state mv module.eks.module.workflow_pool.aws_iam_role_policy_attachment.asg_access module.eks[0].module.workflow_pool[0].aws_iam_role_policy_attachment.asg_access
  gen3 tform state mv module.eks.module.workflow_pool.aws_iam_role_policy_attachment.bucket_write module.eks[0].module.workflow_pool[0].aws_iam_role_policy_attachment.bucket_write
  gen3 tform state mv module.eks.module.workflow_pool.aws_iam_role_policy_attachment.cloudwatch_logs_access module.eks[0].module.workflow_pool[0].aws_iam_role_policy_attachment.cloudwatch_logs_access
  gen3 tform state mv module.eks.module.workflow_pool.aws_iam_role_policy_attachment.eks-node-AmazonEC2ContainerRegistryReadOnly module.eks[0].module.workflow_pool[0].aws_iam_role_policy_attachment.eks-node-AmazonEC2ContainerRegistryReadOnly
  gen3 tform state mv module.eks.module.workflow_pool.aws_iam_role_policy_attachment.eks-node-AmazonEKS_CNI_Policy module.eks[0].module.workflow_pool[0].aws_iam_role_policy_attachment.eks-node-AmazonEKS_CNI_Policy
  gen3 tform state mv module.eks.module.workflow_pool.aws_iam_role_policy_attachment.eks-node-AmazonEKSWorkerNodePolicy module.eks[0].module.workflow_pool[0].aws_iam_role_policy_attachment.eks-node-AmazonEKSWorkerNodePolicy
  gen3 tform state mv module.eks.module.workflow_pool.aws_iam_role_policy_attachment.eks-policy-AmazonEKSClusterPolicy module.eks[0].module.workflow_pool[0].aws_iam_role_policy_attachment.eks-policy-AmazonEKSClusterPolicy
  gen3 tform state mv module.eks.module.workflow_pool.aws_iam_role_policy_attachment.eks-policy-AmazonEKSServicePolicy module.eks[0].module.workflow_pool[0].aws_iam_role_policy_attachment.eks-policy-AmazonEKSServicePolicy
  gen3 tform state mv module.eks.module.workflow_pool.aws_iam_role_policy_attachment.eks-policy-AmazonSSMManagedInstanceCore module.eks[0].module.workflow_pool[0].aws_iam_role_policy_attachment.eks-policy-AmazonSSMManagedInstanceCore
  gen3 tform state mv module.eks.module.workflow_pool.aws_iam_role_policy_attachment.kernel_access module.eks[0].module.workflow_pool[0].aws_iam_role_policy_attachment.kernel_access
  gen3 tform state mv module.eks.module.workflow_pool.aws_launch_configuration.eks_launch_configuration module.eks[0].module.workflow_pool[0].aws_launch_configuration.eks_launch_configuration
  gen3 tform state mv module.eks.module.workflow_pool.aws_security_group.eks_nodes_sg module.eks[0].module.workflow_pool[0].aws_security_group.eks_nodes_sg
  gen3 tform state mv module.eks.module.workflow_pool.aws_security_group_rule.communication_plane_to_nodes module.eks[0].module.workflow_pool[0].aws_security_group_rule.communication_plane_to_nodes
  gen3 tform state mv module.eks.module.workflow_pool.aws_security_group_rule.https_nodes_to_plane module.eks[0].module.workflow_pool[0].aws_security_group_rule.https_nodes_to_plane
  gen3 tform state mv module.eks.module.workflow_pool.aws_security_group_rule.nodes_internode_communications module.eks[0].module.workflow_pool[0].aws_security_group_rule.nodes_internode_communications
  gen3 tform state mv module.eks.module.workflow_pool.aws_security_group_rule.nodes_interpool_communications module.eks[0].module.workflow_pool[0].aws_security_group_rule.nodes_interpool_communications
  gen3 tform state mv module.eks.module.workflow_pool.aws_security_group.ssh module.eks[0].module.workflow_pool[0].aws_security_group.ssh
  gen3 tform state mv module.eks.module.workflow_pool.data.aws_ami.eks_worker module.eks[0].module.workflow_pool[0].data.aws_ami.eks_worker
  gen3 tform state mv module.eks.module.workflow_pool.data.aws_availability_zones.available module.eks[0].module.workflow_pool[0].data.aws_availability_zones.available
  gen3 tform state mv module.eks.module.workflow_pool.data.aws_caller_identity.current module.eks[0].module.workflow_pool[0].data.aws_caller_identity.current
  gen3 tform state mv module.eks.module.workflow_pool.data.aws_region.current module.eks[0].module.workflow_pool[0].data.aws_region.current
  gen3 tform state mv module.eks.module.workflow_pool.data.aws_vpcs.vpcs module.eks[0].module.workflow_pool[0].data.aws_vpcs.vpcs
  gen3 tform state mv module.eks.module.workflow_pool.data.aws_vpc.the_vpc module.eks[0].module.workflow_pool[0].data.aws_vpc.the_vpc
  gen3 tform state mv module.eks.module.workflow_pool.data.template_file.bootstrap module.eks[0].module.workflow_pool[0].data.template_file.bootstrap
  gen3 tform state mv module.eks.module.workflow_pool.data.template_file.ssh_keys module.eks[0].module.workflow_pool[0].data.template_file.ssh_keys
  gen3 tform state mv module.eks.null_resource.config_setup module.eks[0].null_resource.config_setup
  gen3 tform state mv aws_db_instance.db_fence aws_db_instance.db_fence[0]
  gen3 tform state mv aws_db_instance.db_indexd aws_db_instance.db_indexd[0]
  gen3 tform state mv aws_db_instance.db_gdcapi aws_db_instance.db_sheepdog[0]
  gen3 tform state mv aws_route.for_peering  aws_route.for_peering[0]
  gen3 tform state mv module.cdis_vpc.aws_cloudwatch_log_subscription_filter.csoc_subscription  module.cdis_vpc.aws_cloudwatch_log_subscription_filter.csoc_subscription[0]
  gen3 tform state mv module.cdis_vpc.module.data-bucket.aws_cloudtrail.logger_trail module.cdis_vpc.module.data-bucket.module.cloud-trail[0].aws_cloudtrail.logger_trail
  gen3 tform state mv module.cdis_vpc.module.data-bucket.aws_iam_policy.trail_writer module.cdis_vpc.module.data-bucket.module.cloud-trail[0].aws_iam_policy.trail_writer
  gen3 tform state mv module.cdis_vpc.module.data-bucket.aws_iam_role.cloudtrail_to_clouodwatch_writer module.cdis_vpc.module.data-bucket.module.cloud-trail[0].aws_iam_role.cloudtrail_to_cloudwatch_writer
  gen3 tform state mv module.cdis_vpc.module.data-bucket.aws_iam_role_policy_attachment.trail_writer_role module.cdis_vpc.module.data-bucket.module.cloud-trail[0].aws_iam_role_policy_attachment.trail_writer_role
  gen3 tform state mv module.eks.aws_subnet.eks_secondary_subnet[3] module.eks[0].aws_subnet.eks_secondary_subnet[3]
  gen3 tform state mv module.eks.aws_subnet.eks_secondary_subnet[2] module.eks[0].aws_subnet.eks_secondary_subnet[2]
  gen3 tform state mv module.eks.aws_subnet.eks_secondary_subnet[1] module.eks[0].aws_subnet.eks_secondary_subnet[1]
  gen3 tform state mv module.eks.aws_subnet.eks_secondary_subnet[0] module.eks[0].aws_subnet.eks_secondary_subnet[0]
  gen3 tform state mv module.eks.aws_route_table_association.secondary_subnet_kube[3] module.eks[0].aws_route_table_association.secondary_subnet_kube[3]
  gen3 tform state mv module.eks.aws_route_table_association.secondary_subnet_kube[2] module.eks[0].aws_route_table_association.secondary_subnet_kube[2]
  gen3 tform state mv module.eks.aws_route_table_association.secondary_subnet_kube[1] module.eks[0].aws_route_table_association.secondary_subnet_kube[1]
  gen3 tform state mv module.eks.aws_route_table_association.secondary_subnet_kube[0] module.eks[0].aws_route_table_association.secondary_subnet_kube[0]
  if [[ $migrateEs ]]; then
    gen3 tform state mv module.commons_vpc_es.aws_cloudwatch_log_resource_policy.es_logs module.commons_vpc_es[0].aws_cloudwatch_log_resource_policy.es_logs
    gen3 tform state mv module.commons_vpc_es.aws_elasticsearch_domain.gen3_metadata module.commons_vpc_es[0].aws_elasticsearch_domain.gen3_metadata
    gen3 tform state mv module.commons_vpc_es.aws_iam_service_linked_role.es module.commons_vpc_es[0].aws_iam_service_linked_role.es[0]
    gen3 tform state mv module.commons_vpc_es.aws_security_group.private_es module.commons_vpc_es[0].aws_security_group.private_es
    gen3 tform state mv module.commons_vpc_es.module.elasticsearch_alarms.aws_cloudwatch_metric_alarm.elasticsearch_alarm module.commons_vpc_es[0].module.elasticsearch_alarms.aws_cloudwatch_metric_alarm.elasticsearch_alarm
    gen3 tform state mv module.commons_vpc_es.module.elasticsearch_alarms.module.alarms-lambda.data.aws_iam_policy_document.cloudwatch-lambda-policy module.commons_vpc_es[0].module.elasticsearch_alarms.module.alarms-lambda.data.aws_iam_policy_document.cloudwatch-lambda-policy
    gen3 tform state mv module.commons_vpc_es.module.elasticsearch_alarms.module.alarms-lambda.aws_iam_role.lambda_role module.commons_vpc_es[0].module.elasticsearch_alarms.module.alarms-lambda.aws_iam_role.lambda_role
    gen3 tform state mv module.commons_vpc_es.module.elasticsearch_alarms.module.alarms-lambda.aws_iam_role_policy.lambda_policy module.commons_vpc_es[0].module.elasticsearch_alarms.module.alarms-lambda.aws_iam_role_policy.lambda_policy
    gen3 tform state mv module.commons_vpc_es.module.elasticsearch_alarms.module.alarms-lambda.aws_lambda_function.lambda module.commons_vpc_es[0].module.elasticsearch_alarms.module.alarms-lambda.aws_lambda_function.lambda
    gen3 tform state mv module.commons_vpc_es.module.elasticsearch_alarms.module.alarms-lambda.aws_lambda_permission.with_sns module.commons_vpc_es[0].module.elasticsearch_alarms.module.alarms-lambda.aws_lambda_permission.with_sns
    gen3 tform state mv module.commons_vpc_es.module.elasticsearch_alarms.module.alarms-lambda.aws_sns_topic.cloudwatch-alarms module.commons_vpc_es[0].module.elasticsearch_alarms.module.alarms-lambda.aws_sns_topic.cloudwatch-alarms
    gen3 tform state mv module.commons_vpc_es.module.elasticsearch_alarms.module.alarms-lambda.aws_sns_topic_subscription.cloudwatch_lambda module.commons_vpc_es[0].module.elasticsearch_alarms.module.alarms-lambda.aws_sns_topic_subscription.cloudwatch_lambda
  fi
}

gen3_tf_migrate_post_steps() {
  # Migration of resources is complete, but we need to have user manually merge their config.tfvars files and remove duplicate variables to get around tf issues
  gen3_log_info "Please copy over the merged config.tfvars files from the Commons/EKS/ES(if deployed) modules, making sure to remove any duplicate items, as it will cause tf errors"
  if [[ ! $migrateEs ]]; then
    gen3_log_info "Make sure to set deploy_es to false in the new config.tfvars file because you didn't migrate the ES index, unless you want to stand up a new index."
  fi
  # After files have been merged user will need to run the following commands to import the resources needed for the new AWS provider version
  gen3_log_warn "Run the following to workon your new workspace."
  echo "gen3 workon $profile $newWorkspace"
  gen3_log_warn "After doing so run gen3 tfplan to ensure the migration was successful then run the following to import the resources needed for the new AWS provider version(commands are backed up at postMigrationCommands)"
  commands="$(cat - <<EOM
  gen3 tform import --var-file="${GEN3_WORKDIR}/config.tfvars" aws_s3_bucket_acl.kube_bucket kube-${vpc_name}-gen3,private
  gen3 tform import --var-file="${GEN3_WORKDIR}/config.tfvars" aws_s3_bucket_server_side_encryption_configuration.kube_bucket kube-${vpc_name}-gen3
  gen3 tform import --var-file="${GEN3_WORKDIR}/config.tfvars" module.elb_logs.aws_s3_bucket_acl.log_bucket logs-${vpc_name}-gen3,log-delivery-write
  gen3 tform import --var-file="${GEN3_WORKDIR}/config.tfvars" module.elb_logs.aws_s3_bucket_lifecycle_configuration.log_bucket logs-${vpc_name}-gen3
  gen3 tform import --var-file="${GEN3_WORKDIR}/config.tfvars" module.elb_logs.aws_s3_bucket_server_side_encryption_configuration.log_bucket logs-${vpc_name}-gen3
  gen3 tform import --var-file="${GEN3_WORKDIR}/config.tfvars" module.cdis_vpc.module.squid-auto.aws_iam_service_linked_role.squidautoscaling arn:aws:iam::$accountNumber:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling_${vpc_name}_squid
  gen3 tform import --var-file="${GEN3_WORKDIR}/config.tfvars" module.cdis_vpc.module.data-bucket.module.cloud-trail[0].aws_iam_role_policy_attachment.trail_writer_role ${vpc_name}_data-bucket_ct_to_cwl_writer/arn:aws:iam::$accountNumber:policy/trail_write_to_cwl_${vpc_name}
  gen3 tform import --var-file="${GEN3_WORKDIR}/config.tfvars" module.cdis_vpc.module.data-bucket.aws_s3_bucket_acl.data_bucket ${vpc_name}-data-bucket,private
  gen3 tform import --var-file="${GEN3_WORKDIR}/config.tfvars" module.cdis_vpc.module.data-bucket.aws_s3_bucket_logging.data_bucket ${vpc_name}-data-bucket
  gen3 tform import --var-file="${GEN3_WORKDIR}/config.tfvars" module.cdis_vpc.module.data-bucket.aws_s3_bucket_server_side_encryption_configuration.data_bucket ${vpc_name}-data-bucket
  gen3 tform import --var-file="${GEN3_WORKDIR}/config.tfvars" module.cdis_vpc.module.data-bucket.aws_s3_bucket_acl.log_bucket ${vpc_name}-data-bucket-logs,log-delivery-write
  gen3 tform import --var-file="${GEN3_WORKDIR}/config.tfvars" module.cdis_vpc.module.data-bucket.aws_s3_bucket_lifecycle_configuration.log_bucket ${vpc_name}-data-bucket-logs
  gen3 tform import --var-file="${GEN3_WORKDIR}/config.tfvars" module.cdis_vpc.module.data-bucket.aws_s3_bucket_server_side_encryption_configuration.log_bucket ${vpc_name}-data-bucket-logs
EOM
)"
  echo "$commands" | tee ~/postMigrationCommands
}


if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  if [[ -z "$1" || "$1" =~ ^-*help$ ]]; then
    gen3_logs_help
    exit 0
  fi
  for command in $@; do
    if [[ $# -gt 0 ]]; then
      command="$1"
      shift
    fi
    case "$command" in
      "--old-workspace")
        oldWorkspace="$1"
        ;;
      "--new-workspace")
        newWorkspace="$1"
        ;;
      "--profile")
        profile="$1"
        ;;
      "--migrate-es")
        migrateEs=true
        ;;
    esac
  done
  if [[ -z $oldWorkspace || -z $newWorkspace || -z $profile ]]; then
    gen3_log_err "old workspace, new workspace and profile are required variables, please ensure you set them correctly and try again"
    exit 1
  fi
  # Try to ensure ES will get migrated only if people have it running, even if they forget the flag
  if [[ ! $migrateEs ]]; then
    promptUser="$(
      yesno=no
      gen3_log_warn "Is there an Elasticsearch database running in this commons that you would like to migrate? (y/n)"
      read -r yesno
      echo "$yesno"
    )"
    if [[ ! $promptUser =~ ^y(es)?$ ]]; then
      migrateEs=false
    fi
  fi
  if [[ -z $vpc_name ]]; then
    vpc_name=$(gen3 api environment)
  fi
  
  gen3_tf_migrate_prep_tfstate
  gen3_tf_migrate_update_providers
  gen3_tf_migrate_move_resources
  gen3_tf_migrate_post_steps
fi
