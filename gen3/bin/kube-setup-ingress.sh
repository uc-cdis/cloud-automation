#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/kube-setup-init"
gen3_load "gen3/lib/g3k_manifest"

# Deploy WAF if flag set in manifest
manifestPath=$(g3k_manifest_path)
deployWaf="$(jq -r ".[\"global\"][\"waf_enabled\"]" < "$manifestPath" | tr '[:upper:]' '[:lower:]')"

ctx="$(g3kubectl config current-context)"
ctxNamespace="$(g3kubectl config view -ojson | jq -r ".contexts | map(select(.name==\"$ctx\")) | .[0] | .context.namespace")"

scriptDir="${GEN3_HOME}/kube/services/ingress"

gen3_ingress_setup_waf() {
    gen3_log_info "Starting GPE-312 waf setup"
    #variable to see if WAF already exists
    export waf=`aws wafv2 list-web-acls --scope REGIONAL | jq -r '.WebACLs[]|select(.Name| contains(env.vpc_name)).Name'`
if [[ -z $waf ]]; then
    gen3_log_info "Creating Web ACL. This may take a few minutes."
    aws wafv2 create-web-acl\
        --name $vpc_name-waf \
        --scope REGIONAL \
        --default-action Allow={} \
        --visibility-config SampledRequestsEnabled=true,CloudWatchMetricsEnabled=true,MetricName=GPE-312WebAclMetrics \
        --rules file://${GEN3_HOME}/gen3/bin/waf-rules-GPE-312.json \
        --region us-east-1
    #Need to sleep to avoid "WAFUnavailableEntityException" error since the waf takes a bit to spin up
    sleep 300
else
    gen3_log_info "WAF already exists. Skipping..."
fi
    gen3_log_info "Attaching ACL to ALB."
    export acl_arn=`aws wafv2 list-web-acls --scope REGIONAL | jq -r '.WebACLs[]|select(.Name| contains(env.vpc_name)).ARN'`
    export alb_name=`kubectl get ingress gen3-ingress | awk '{print $4}' | tail +2 |  sed 's/^\([A-Za-z0-9]*-[A-Za-z0-9]*-[A-Za-z0-9]*\).*/\1/;q'`
    export alb_arn=`aws elbv2 describe-load-balancers --name $alb_name | yq -r .LoadBalancers[0].LoadBalancerArn`
    export association=`aws wafv2 list-resources-for-web-acl --web-acl-arn $acl_arn | grep $alb_arn| sed -e 's/^[ \t]*//' | sed -e 's/^"//' -e 's/"$//'`
    #variable to see if the association already exists
    echo "acl_arn: $acl_arn"
    echo "alb_arn: $alb_arn"
if [[ $association != $alb_arn ]]; then
    aws wafv2 associate-web-acl\
        --web-acl-arn $acl_arn \
        --resource-arn $alb_arn \
        --region us-east-1

    gen3_log_info "Add ACL arn annotation to ALB ingress"
    kubectl annotate ingress gen3-ingress "alb.ingress.kubernetes.io/wafv2-acl-arn=$acl_arn"
else
    gen3_log_info "ALB is already associated with ACL. Skipping..."
fi
}


gen3_ingress_setup_role() {
# https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/installation/
# https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.1/docs/install/iam_policy.json
# only do this if we are running in the default namespace
  local saName="aws-load-balancer-controller"
  local roleName=$(gen3 api safe-name ingress)
  local policyName=$(gen3 api safe-name ingress-policy)
  local ingressPolicy="$(mktemp "$XDG_RUNTIME_DIR/ingressPolicy.json_XXXXXX")"
  local arPolicyFile="$(mktemp "$XDG_RUNTIME_DIR/arPolicy.json_XXXXXX")"

  # Create an inline policy for the ingress-controller
  cat - > "$ingressPolicy" <<EOM
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateServiceLinkedRole"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:AWSServiceName": "elasticloadbalancing.amazonaws.com"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAddresses",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeVpcs",
                "ec2:DescribeVpcPeeringConnections",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeInstances",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeTags",
                "ec2:GetCoipPoolUsage",
                "ec2:DescribeCoipPools",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeListenerCertificates",
                "elasticloadbalancing:DescribeSSLPolicies",
                "elasticloadbalancing:DescribeRules",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetGroupAttributes",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:DescribeTags"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cognito-idp:DescribeUserPoolClient",
                "acm:ListCertificates",
                "acm:DescribeCertificate",
                "iam:ListServerCertificates",
                "iam:GetServerCertificate",
                "waf-regional:GetWebACL",
                "waf-regional:GetWebACLForResource",
                "waf-regional:AssociateWebACL",
                "waf-regional:DisassociateWebACL",
                "wafv2:GetWebACL",
                "wafv2:GetWebACLForResource",
                "wafv2:AssociateWebACL",
                "wafv2:DisassociateWebACL",
                "shield:GetSubscriptionState",
                "shield:DescribeProtection",
                "shield:CreateProtection",
                "shield:DeleteProtection"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateSecurityGroup"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags"
            ],
            "Resource": "arn:aws:ec2:*:*:security-group/*",
            "Condition": {
                "StringEquals": {
                    "ec2:CreateAction": "CreateSecurityGroup"
                },
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags",
                "ec2:DeleteTags"
            ],
            "Resource": "arn:aws:ec2:*:*:security-group/*",
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:DeleteSecurityGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateTargetGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:CreateRule",
                "elasticloadbalancing:DeleteRule"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ],
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:SetIpAddressType",
                "elasticloadbalancing:SetSecurityGroups",
                "elasticloadbalancing:SetSubnets",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:ModifyTargetGroupAttributes",
                "elasticloadbalancing:DeleteTargetGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:DeregisterTargets"
            ],
            "Resource": "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:SetWebAcl",
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:AddListenerCertificates",
                "elasticloadbalancing:RemoveListenerCertificates",
                "elasticloadbalancing:ModifyRule"
            ],
            "Resource": "*"
        }
    ]
}
EOM
  if ! gen3 awsrole info "$roleName" "kube-system" > /dev/null; then # setup role
    gen3_log_info "creating IAM role for ingress: $roleName, linking to sa $saName"
    gen3 awsrole create "$roleName" "$saName" "kube-system" || return 1
    aws iam put-role-policy --role-name "$roleName" --policy-document file://${ingressPolicy} --policy-name "$policyName" 1>&2
    gen3 awsrole sa-annotate $saName $roleName kube-system
  else
    # update the annotation - just to be thorough
    gen3 awsrole sa-annotate "$saName" "$roleName" kube-system
  fi
}

gen3_ingress_deploy_helm_chart() {
  kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"
  if (! helm status aws-load-balancer-controller -n kube-system > /dev/null 2>&1 )  || [[ "$1" == "--force" ]]; then
    helm repo add eks https://aws.github.io/eks-charts 2> >(grep -v 'This is insecure' >&2)
    helm repo update 2> >(grep -v 'This is insecure' >&2)

   #  # TODO: Move to values.yaml file
    helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=$(gen3 api environment) --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller 2> >(grep -v 'This is insecure' >&2)
  else
    gen3_log_info "kube-setup-ingress exiting - ingress already deployed, use --force to redeploy"
  fi
}

if [[ "$ctxNamespace" == "default" || "$ctxNamespace" == "null" ]]; then
  # Create role/SA for the alb's
  gen3_ingress_setup_role
  # Deploy the aws-load-balancer-controller helm chart and upgrade if --force flag applied
  gen3_ingress_deploy_helm_chart $1
else
  if [[ -z $(kubectl get sa -n kube-system | grep aws-load-balancer-controller) ]]; then
    gen3_log_err "Please run this in the default namespace first to setup the necessary roles"
    exit 1
  fi
fi


gen3_log_info "Applying ingress resource"
export ARN=$(g3kubectl get configmap global --output=jsonpath='{.data.revproxy_arn}')
g3kubectl apply -f "${GEN3_HOME}/kube/services/revproxy/revproxy-service.yaml"
envsubst <$scriptDir/ingress.yaml | g3kubectl apply -f -
if [ "$deployWaf" = true ]; then
  gen3_ingress_setup_waf
fi