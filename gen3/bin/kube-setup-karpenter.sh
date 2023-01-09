#!/bin/bash

#set -i

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


gen3_deploy_karpenter() {
  # If the karpenter namespace doesn't exist or the force flag isn't in place then deploy
  if [[ -z $(g3kubectl get namespaces | grep karpenter) ]]  || [[ "$1" == "--force" ]]; then
    karpenter=${karpenter:-v0.22.0}
    echo '{
        "Statement": [
            {
                "Action": [
                    "ssm:GetParameter",
                    "iam:PassRole",
                    "ec2:DescribeImages",
                    "ec2:RunInstances",
                    "ec2:DescribeSubnets",
                    "ec2:DescribeSecurityGroups",
                    "ec2:DescribeLaunchTemplates",
                    "ec2:DescribeInstances",
                    "ec2:DescribeInstanceTypes",
                    "ec2:DescribeInstanceTypeOfferings",
                    "ec2:DescribeAvailabilityZones",
                    "ec2:DeleteLaunchTemplate",
                    "ec2:CreateTags",
                    "ec2:CreateLaunchTemplate",
                    "ec2:CreateFleet",
                    "ec2:DescribeSpotPriceHistory",
                    "pricing:GetProducts"
                ],
                "Effect": "Allow",
                "Resource": "*",
                "Sid": "Karpenter"
            },
            {
                "Action": "ec2:TerminateInstances",
                "Condition": {
                    "StringLike": {
                        "ec2:ResourceTag/Name": "*karpenter*"
                    }
                },
                "Effect": "Allow",
                "Resource": "*",
                "Sid": "ConditionalEC2Termination"
            }
        ],
        "Version": "2012-10-17"
    }' > controller-policy.json

    g3kubectl create namespace karpenter 2> /dev/null || true
    gen3 awsrole create "karpenter-controller-role-$vpc_name" karpenter "karpenter" || true
    # Have to delete SA because helm chart will create the SA and there will be a conflict
    g3kubectl delete sa karpenter -n karpenter
    aws iam put-role-policy --role-name "karpenter-controller-role-$vpc_name" --policy-document file://controller-policy.json --policy-name "karpenter-controller-policy" 1>&2 || true
    # Need to tag the subnets/sg's so that karpenter can discover them automatically
    subnets=$(aws ec2 describe-subnets --filter 'Name=tag:Environment,Values='$vpc_name'' 'Name=tag:Name,Values=eks_private_*' --query 'Subnets[].SubnetId' --output text)
    security_groups=$(aws ec2 describe-security-groups --filter 'Name=tag:Name,Values='$vpc_name'-nodes-sg,ssh_eks_'$vpc_name'' --query 'SecurityGroups[].GroupId' --output text)
    security_groups_jupyter=$(aws ec2 describe-security-groups --filter 'Name=tag:Name,Values='$vpc_name'-nodes-sg-jupyter,ssh_eks_'$vpc_name'-nodepool-jupyter' --query 'SecurityGroups[].GroupId' --output text)
    cluster_endpoint="$(aws eks describe-cluster --name ${vpc_name} --query "cluster.endpoint" --output text)"

    aws ec2 create-tags --tags "Key=karpenter.sh/discovery,Value=${vpc_name}" --resources ${security_groups}
    aws ec2 create-tags --tags "Key=karpenter.sh/discovery,Value=true" --resources ${subnets}
    aws ec2 create-tags --tags "Key=karpenter.sh/discovery,Value=${vpc_name}-jupyter" --resources ${security_groups_jupyter}
    helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter --version ${karpenter} --namespace karpenter \
        --set settings.aws.defaultInstanceProfile=${vpc_name}_EKS_workers \
        --set settings.aws.clusterEndpoint="${cluster_endpoint}" \
        --set settings.aws.clusterName=${vpc_name} \
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::$(aws sts get-caller-identity --output text --query 'Account'):role/gen3_service/karpenter-controller-role-${vpc_name}"
   # sleep for a little bit so CRD's can be created for the provisioner/node template
   sleep 10
  fi
  gen3 kube-setup-autoscaler --remove
  g3k_kv_filter ${GEN3_HOME}/kube/services/karpenter/nodeTemplateDefault.yaml VPC_NAME ${vpc_name} | g3kubectl apply -f -
  g3k_kv_filter ${GEN3_HOME}/kube/services/karpenter/nodeTemplateJupyter.yaml VPC_NAME ${vpc_name} | g3kubectl apply -f -
  g3kubectl apply -f ${GEN3_HOME}/kube/services/karpenter/provisionerDefault.yaml
  g3kubectl apply -f ${GEN3_HOME}/kube/services/karpenter/provisionerJupyter.yaml
}

gen3_remove_karpenter() {
  aws iam delete-role-policy --role-name "karpenter-controller-role-$vpc_name" --policy-name "karpenter-controller-policy" 1>&2 || true
  aws iam delete-role --role-name "karpenter-controller-role-$vpc_name"
  helm uninstall karpenter -n karpenter 
  g3kubectl delete namespace karpenter
  gen3 kube-setup-autoscaler
}

#---------- main

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  # Support sourcing this file for test suite
  command="$1"
  shift
  case "$command" in
    "deploy")
      gen3_deploy_karpenter
      ;;
    "remove")
      gen3_remove_karpenter
      ;;
    *)
      gen3_deploy_karpenter
      ;;
  esac
fi
