#!/bin/bash

#set -e

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

ctx="$(g3kubectl config current-context)"
ctxNamespace="$(g3kubectl config view -ojson | jq -r ".contexts | map(select(.name==\"$ctx\")) | .[0] | .context.namespace")"

gen3_deploy_karpenter() {
  # Only do cluster level changes in the default namespace to prevent conflicts
  if [[ ("$ctxNamespace" == "default" || "$ctxNamespace" == "null") ]]; then
    gen3_log_info "Deploying karpenter"
    # If the karpenter namespace doesn't exist or the force flag isn't in place then deploy
    if [[ ( -z $(g3kubectl get namespaces | grep karpenter) || $FORCE == "true" ) ]]; then
      gen3_log_info "Ensuring that the spot instance service linked role is setup"
      # Ensure the spot instance service linked role is setup
      # It is required for running spot instances
      #### Uncomment this when we fix the sqs helper to allow for usage by more than one service
      #gen3_create_karpenter_sqs_eventbridge
      aws iam create-service-linked-role --aws-service-name spot.amazonaws.com || true
      if g3k_config_lookup .global.karpenter_version; then
        karpenter=$(g3k_config_lookup .global.karpenter_version)
      fi
      export clusterversion=`kubectl version -o json | jq -r .serverVersion.minor`
      if [ "${clusterversion}" = "25+" ]; then
        karpenter=${karpenter:-v0.27.0}
      elif [ "${clusterversion}" = "24+" ]; then
        karpenter=${karpenter:-v0.24.0}
      else
        karpenter=${karpenter:-v0.22.0}
      fi    
      local queue_name="$(gen3 api safe-name karpenter-sqs)"
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
                  "Action": [
                      "sqs:DeleteMessage",
                      "sqs:GetQueueAttributes",
                      "sqs:GetQueueUrl",
                      "sqs:ReceiveMessage"
                  ],
                  "Effect": "Allow",
      "Resource": "arn:aws:sqs:*:'$(aws sts get-caller-identity --output text --query "Account")':karpenter-sqs-'$(echo vpc_name)'",
                  "Sid": "Karpenter2"
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
              },
              {
                  "Sid": "VisualEditor0",
                  "Effect": "Allow",
                  "Action": [
                      "kms:*"
                  ],
                  "Resource": "*"
              }
          ],
          "Version": "2012-10-17"
      }' > $XDG_RUNTIME_DIR/controller-policy.json

      gen3_log_info "Creating karpenter namespace"
      g3kubectl create namespace karpenter 2> /dev/null || true

      gen3_log_info "Creating karpenter AWS role and k8s service accounts"
      gen3 awsrole create "karpenter-controller-role-$vpc_name" karpenter "karpenter" || true
      gen3 awsrole sa-annotate karpenter "karpenter-controller-role-$vpc_name" karpenter || true
      # Have to delete SA because helm chart will create the SA and there will be a conflict

      gen3_log_info "Have to delete SA because helm chart will create the SA and there will be a conflict"
      #g3kubectl delete sa karpenter -n karpenter

      gen3_log_info "aws iam put-role-policy --role-name "karpenter-controller-role-$vpc_name" --policy-document file://$XDG_RUNTIME_DIR/controller-policy.json --policy-name "karpenter-controller-policy" 1>&2 || true"
      aws iam put-role-policy --role-name "karpenter-controller-role-$vpc_name" --policy-document file://$XDG_RUNTIME_DIR/controller-policy.json --policy-name "karpenter-controller-policy" 1>&2 || true
      gen3_log_info "Need to tag the subnets/sg's so that karpenter can discover them automatically"
      # Need to tag the subnets/sg's so that karpenter can discover them automatically
      subnets=$(aws ec2 describe-subnets --filter 'Name=tag:Environment,Values='$vpc_name'' 'Name=tag:Name,Values=eks_private_*' --query 'Subnets[].SubnetId' --output text)
      # Will apprend secondary CIDR block subnets to be tagged as well, and if none are found then will not append anything to list
      subnets+=" $(aws ec2 describe-subnets --filter 'Name=tag:Environment,Values='$vpc_name'' 'Name=tag:Name,Values=eks_secondary_cidr_subnet_*' --query 'Subnets[].SubnetId' --output text)"
      security_groups=$(aws ec2 describe-security-groups --filter 'Name=tag:Name,Values='$vpc_name'-nodes-sg,ssh_eks_'$vpc_name'' --query 'SecurityGroups[].GroupId' --output text) || true
      security_groups_jupyter=$(aws ec2 describe-security-groups --filter 'Name=tag:Name,Values='$vpc_name'-nodes-sg-jupyter,ssh_eks_'$vpc_name'-nodepool-jupyter' --query 'SecurityGroups[].GroupId' --output text) || true
      security_groups_workflow=$(aws ec2 describe-security-groups --filter 'Name=tag:Name,Values='$vpc_name'-nodes-sg-workflow,ssh_eks_'$vpc_name'-nodepool-workflow' --query 'SecurityGroups[].GroupId' --output text) || true
      cluster_endpoint="$(aws eks describe-cluster --name ${vpc_name} --query "cluster.endpoint" --output text)"

      aws ec2 create-tags --tags "Key=karpenter.sh/discovery,Value=${vpc_name}" --resources ${security_groups} || true
      aws ec2 create-tags --tags "Key=karpenter.sh/discovery,Value=${vpc_name}" --resources ${subnets} || true
      aws ec2 create-tags --tags "Key=karpenter.sh/discovery,Value=${vpc_name}-jupyter" --resources ${security_groups_jupyter} || true
      aws ec2 create-tags --tags "Key=karpenter.sh/discovery,Value=${vpc_name}-workflow" --resources ${security_groups_workflow} || true
      echo '{
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Condition": {
              "ArnLike": {
          "aws:SourceArn": "arn:aws:eks:us-east-1:'$(aws sts get-caller-identity --output text --query "Account")':fargateprofile/'$(echo $vpc_name)'/*"
              }
            },
              "Principal": {
              "Service": "eks-fargate-pods.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
          }
        ]
      }' > $XDG_RUNTIME_DIR/fargate-policy.json
      aws iam create-role   --role-name AmazonEKSFargatePodExecutionRole-${vpc_name} --assume-role-policy-document file://"$XDG_RUNTIME_DIR/fargate-policy.json" || true
      aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy  --role-name AmazonEKSFargatePodExecutionRole-${vpc_name} || true
      # Wait for IAM changes to take effect
      sleep 15
      aws eks create-fargate-profile --fargate-profile-name karpenter-profile --cluster-name $vpc_name --pod-execution-role-arn arn:aws:iam::$(aws sts get-caller-identity --output text --query "Account"):role/AmazonEKSFargatePodExecutionRole-${vpc_name} --subnets $subnets --selectors '{"namespace": "karpenter"}' || true
      gen3_log_info "Installing karpenter using helm"
      helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter --version ${karpenter} --namespace karpenter --wait \
          --set settings.aws.defaultInstanceProfile=${vpc_name}_EKS_workers \
          --set settings.aws.clusterEndpoint="${cluster_endpoint}" \
          --set settings.aws.clusterName=${vpc_name} \
          --set settings.aws.interruptionQueueName="${queue_name}" \
          --set serviceAccount.name=karpenter \
          --set serviceAccount.create=false \
          --set controller.env[0].name=AWS_REGION \
          --set controller.env[0].value=us-east-1 \
          --set controller.resources.requests.memory="2Gi" \
          --set controller.resources.requests.cpu="2" \
          --set controller.resources.limits.memory="2Gi" \
          --set controller.resources.limits.cpu="2"
    fi
    gen3 awsrole sa-annotate karpenter "karpenter-controller-role-$vpc_name" karpenter
    gen3_log_info "Remove cluster-autoscaler"
    gen3 kube-setup-autoscaler --remove
    # Ensure that fluentd is updated if karpenter is deployed to prevent containerd logging issues
    gen3 kube-setup-fluentd --force
    gen3_update_karpenter_configs
  fi
}

gen3_update_karpenter_configs() {
  # depoloy node templates and provisioners if not set in manifest
  if [[ -d $(g3k_manifest_init)/$(g3k_hostname)/manifests/karpenter ]]; then
    gen3_log_info "karpenter manifest found, skipping node template and provisioner deployment"
    # apply each manifest in the karpenter folder
    for manifest in $(g3k_manifest_init)/$(g3k_hostname)/manifests/karpenter/*.yaml; do
      g3k_kv_filter $manifest VPC_NAME ${vpc_name} | g3kubectl apply -f -
    done
  else
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
    if [[ $GPU ]]; then
      g3kubectl apply -f ${GEN3_HOME}/kube/services/karpenter/provisionerGPU.yaml
      g3kubectl apply -f ${GEN3_HOME}/kube/services/karpenter/provisionerGPUShared.yaml
      g3kubectl apply -f ${GEN3_HOME}/kube/services/karpenter/nodeTemplateGPU.yaml
      helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
      helm repo update
      helm upgrade -i nvdp nvdp/nvidia-device-plugin \
        --namespace nvidia-device-plugin \
        --create-namespace -f ${GEN3_HOME}/kube/services/karpenter/nvdp.yaml
    fi
    g3kubectl apply -f ${GEN3_HOME}/kube/services/karpenter/provisionerJupyter.yaml
    g3kubectl apply -f ${GEN3_HOME}/kube/services/karpenter/provisionerWorkflow.yaml
  fi
}

gen3_create_karpenter_sqs_eventbridge() {
  local queue_name="$(gen3 api safe-name karpenter-sqs)"
  local eventbridge_rule_name="karpenter-eventbridge-${vpc_name}"
  gen3 sqs create-queue-if-not-exist karpenter-sqs >> "$XDG_RUNTIME_DIR/sqs-${vpc_name}.json"
  local queue_url=$(cat "$XDG_RUNTIME_DIR/sqs-${vpc_name}.json" | jq -r '.url')
  local queue_arn=$(cat "$XDG_RUNTIME_DIR/sqs-${vpc_name}.json" | jq -r '.arn')
  # Create eventbridge rules
  aws events put-rule --name "Karpenter-${vpc_name}-SpotInterruptionRule" --event-pattern '{"source": ["aws.ec2"], "detail-type": ["EC2 Spot Instance Interruption Warning"]}' 2> /dev/null
  aws events put-rule --name "Karpenter-${vpc_name}-RebalanceRule" --event-pattern '{"source": ["aws.ec2"], "detail-type": ["EC2 Instance Rebalance Recommendation"]}' 2> /dev/null
  aws events put-rule --name "Karpenter-${vpc_name}-ScheduledChangeRule" --event-pattern '{"source": ["aws.health"], "detail-type": ["AWS Health Event"]}' 2> /dev/null
  aws events put-rule --name "Karpenter-${vpc_name}-InstanceStateChangeRule" --event-pattern '{"source": ["aws.ec2"], "detail-type": ["EC2 Instance State-change Notification"]}' 2> /dev/null
  # Add SQS as a target for the eventbridge rules
  aws events put-targets --rule "Karpenter-${vpc_name}-SpotInterruptionRule" --targets "Id"="1","Arn"="${queue_arn}" 2> /dev/null || true
  aws events put-targets --rule "Karpenter-${vpc_name}-RebalanceRule" --targets "Id"="1","Arn"="${queue_arn}" 2> /dev/null || true
  aws events put-targets --rule "Karpenter-${vpc_name}-ScheduledChangeRule" --targets "Id"="1","Arn"="${queue_arn}" 2> /dev/null || true
  aws events put-targets --rule "Karpenter-${vpc_name}-InstanceStateChangeRule" --targets "Id"="1","Arn"="${queue_arn}" 2> /dev/null || true
  aws sqs set-queue-attributes --queue-url "${queue_url}" --attributes "Policy"="$(aws sqs get-queue-attributes --queue-url "${queue_url}" --attribute-names "Policy" --query "Attributes.Policy" --output text | jq -r '.Statement += [{"Sid": "AllowKarpenter", "Effect": "Allow", "Principal": {"Service": ["sqs.amazonaws.com","events.amazonaws.com"]}, "Action": "sqs:SendMessage", "Resource": "'${queue_arn}'"}]')" 2> /dev/null || true
  #g3k_kv_filter ${GEN3_HOME}/kube/services/karpenter/karpenter-global-settings.yaml SQS_NAME ${queue_name} | g3kubectl apply -f -
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
    "update")
      gen3_update_karpenter_configs
      ;;
    *)
      gen3_deploy_karpenter
      ;;
  esac
fi
