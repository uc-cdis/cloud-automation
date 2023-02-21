#!/bin/bash

#set -e

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

ctx="$(g3kubectl config current-context)"
ctxNamespace="$(g3kubectl config view -ojson | jq -r ".contexts | map(select(.name==\"$ctx\")) | .[0] | .context.namespace")"

gen3_deploy_karpenter() {
  gen3_log_info "Deploying karpenter"
  # If the karpenter namespace doesn't exist or the force flag isn't in place then deploy
  if [[( -z $(g3kubectl get namespaces | grep karpenter) || $FORCE == "true" ) && ("$ctxNamespace" == "default" || "$ctxNamespace" == "null")]]; then
    gen3_log_info "Ensuring that the spot instance service linked role is setup"
    # Ensure the spot instance service linked role is setup
    # It is required for running spot instances
    aws iam create-service-linked-role --aws-service-name spot.amazonaws.com || true
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

    gen3_log_info "Creating karpenter namespace"
    g3kubectl create namespace karpenter 2> /dev/null || true

    gen3_log_info "Creating karpenter AWS role and k8s service accounts"
    gen3 awsrole create "karpenter-controller-role-$vpc_name" karpenter "karpenter" || true
    # Have to delete SA because helm chart will create the SA and there will be a conflict

    gen3_log_info "Have to delete SA because helm chart will create the SA and there will be a conflict"
    g3kubectl delete sa karpenter -n karpenter


    gen3_log_info "aws iam put-role-policy --role-name "karpenter-controller-role-$vpc_name" --policy-document file://controller-policy.json --policy-name "karpenter-controller-policy" 1>&2 || true"
    aws iam put-role-policy --role-name "karpenter-controller-role-$vpc_name" --policy-document file://controller-policy.json --policy-name "karpenter-controller-policy" 1>&2 || true
    
    gen3_log_info "Need to tag the subnets/sg's so that karpenter can discover them automatically"
    # Need to tag the subnets/sg's so that karpenter can discover them automatically
    subnets=$(aws ec2 describe-subnets --filter 'Name=tag:Environment,Values='$vpc_name'' 'Name=tag:Name,Values=eks_private_*' --query 'Subnets[].SubnetId' --output text)
    security_groups=$(aws ec2 describe-security-groups --filter 'Name=tag:Name,Values='$vpc_name'-nodes-sg,ssh_eks_'$vpc_name'' --query 'SecurityGroups[].GroupId' --output text)
    security_groups_jupyter=$(aws ec2 describe-security-groups --filter 'Name=tag:Name,Values='$vpc_name'-nodes-sg-jupyter,ssh_eks_'$vpc_name'-nodepool-jupyter' --query 'SecurityGroups[].GroupId' --output text)
    security_groups_workflow=$(aws ec2 describe-security-groups --filter 'Name=tag:Name,Values='$vpc_name'-nodes-sg-workflow,ssh_eks_'$vpc_name'-nodepool-workflow' --query 'SecurityGroups[].GroupId' --output text)    
    cluster_endpoint="$(aws eks describe-cluster --name ${vpc_name} --query "cluster.endpoint" --output text)"

    aws ec2 create-tags --tags "Key=karpenter.sh/discovery,Value=${vpc_name}" --resources ${security_groups}
    aws ec2 create-tags --tags "Key=karpenter.sh/discovery,Value=${vpc_name}" --resources ${subnets}
    aws ec2 create-tags --tags "Key=karpenter.sh/discovery,Value=${vpc_name}-jupyter" --resources ${security_groups_jupyter}
    aws ec2 create-tags --tags "Key=karpenter.sh/discovery,Value=${vpc_name}-worfklow" --resources ${security_groups_workflow}


    gen3_log_info "Installing karpenter using helm"

    helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter --version ${karpenter} --namespace karpenter \
        --set settings.aws.defaultInstanceProfile=${vpc_name}_EKS_workers \
        --set settings.aws.clusterEndpoint="${cluster_endpoint}" \
        --set settings.aws.clusterName=${vpc_name} \
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::$(aws sts get-caller-identity --output text --query 'Account'):role/gen3_service/karpenter-controller-role-${vpc_name}"
   
   gen3_log_info "sleep for a little bit so CRD's can be created for the provisioner/node template"
   # sleep for a little bit so CRD's can be created for the provisioner/node template
   sleep 10
   gen3_log_info "Deploy AWS node termination handler so that spot instances can be preemptively spun up before old instances stop"
   # Deploy AWS node termination handler so that spot instances can be preemptively spun up before old instances stop
   kubectl apply -f https://github.com/aws/aws-node-termination-handler/releases/download/v1.18.1/all-resources.yaml
  fi

  gen3_log_info "Remove cluster-autoscaler"
  gen3 kube-setup-autoscaler --remove

  gen3_log_info "Adding node templates for karpenter"
  g3k_kv_filter ${GEN3_HOME}/kube/services/karpenter/nodeTemplateDefault.yaml VPC_NAME ${vpc_name} | g3kubectl apply -f -
  g3k_kv_filter ${GEN3_HOME}/kube/services/karpenter/nodeTemplateJupyter.yaml VPC_NAME ${vpc_name} | g3kubectl apply -f -
  g3k_kv_filter ${GEN3_HOME}/kube/services/karpenter/nodeTemplateWorkflow.yaml VPC_NAME ${vpc_name} | g3kubectl apply -f -
  if [[ $ARM ]]; then
    gen3_log_info "Deploy binfmt daemonset so the emulation tools run on arm nodes"
    # Deploy binfmt daemonset so the emulation tools run on arm nodes
    g3kubectl apply -f ${GEN3_HOME}/kube/services/karpenter/binfmt.yaml
    g3kubectl apply -f ${GEN3_HOME}/kube/services/karpenter/provisionerArm.yaml
  else
    g3kubectl apply -f ${GEN3_HOME}/kube/services/karpenter/provisionerDefault.yaml    
  fi
  g3kubectl apply -f ${GEN3_HOME}/kube/services/karpenter/provisionerJupyter.yaml
  g3kubectl apply -f ${GEN3_HOME}/kube/services/karpenter/provisionerWorkflow.yaml
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
      for flag in $@; do
        if [[ $# -gt 0 ]]; then
          flag="$1"
          shift
        fi
        case "$flag" in
          "--force")
            FORCE=true
            ;;
          "--arm")
            ARM=true
            ;;
        esac
      done
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
