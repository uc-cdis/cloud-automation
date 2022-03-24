#!/bin/bash
#



source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/kube-setup-init"


ctx="$(g3kubectl config current-context)"
ctxNamespace="$(g3kubectl config view -ojson | jq -r ".contexts | map(select(.name==\"$ctx\")) | .[0] | .context.namespace")"


# https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/installation/
# https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.1/docs/install/iam_policy.json
# only do this if we are running in the default namespace
if [[ "$ctxNamespace" == "default" || "$ctxNamespace" == "null" ]]; then


#-----------------------------------------------------------------------------------------------------------------------
  # IAM stuff

#   - IAM permissions setup so we can do ALB stuff 
#     - associate IAM policy with a service account
# - Deploy CRDS's
#   - kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
  
  # make the 
  saName="ingress-controller-service-account"
  roleName=$(gen3 api safe-name ingress)
  ingressPolicy="$(mktemp "$XDG_RUNTIME_DIR/ingressPolicy.json_XXXXXX")"
  # Create an inline policy for the ingress-controller
  cat - > "$ingressPolicy" <<EOM
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect":"Allow",
         "Action":[
            "iam:CreateServiceLinkedRole"
         ],
         "Resource":"*",
         "Condition":{
            "StringEquals":{
               "iam":"AWSServiceName":"elasticloadbalancing.amazonaws.com"
            }
         }
      },
      {
         "Effect":"Allow",
         "Action":[
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
         "Resource":"*"
      },
      {
         "Effect":"Allow",
         "Action":[
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
         "Resource":"*"
      },
      {
         "Effect":"Allow",
         "Action":[
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:RevokeSecurityGroupIngress"
         ],
         "Resource":"*"
      },
      {
         "Effect":"Allow",
         "Action":[
            "ec2:CreateSecurityGroup"
         ],
         "Resource":"*"
      },
      {
         "Effect":"Allow",
         "Action":[
            "ec2:CreateTags"
         ],
         "Resource":"arn:aws:ec2:*:*:security-group/*",
         "Condition":{
            "StringEquals":{
               "ec2":"CreateAction":"CreateSecurityGroup"
            },
            null:{
               "aws":"RequestTag/elbv2.k8s.aws/cluster":"false"
            }
         }
      },
      {
         "Effect":"Allow",
         "Action":[
            "ec2:CreateTags",
            "ec2:DeleteTags"
         ],
         "Resource":"arn:aws:ec2:*:*:security-group/*",
         "Condition":{
            null:{
               "aws":"RequestTag/elbv2.k8s.aws/cluster":"true",
               "aws":"ResourceTag/elbv2.k8s.aws/cluster":"false"
            }
         }
      },
      {
         "Effect":"Allow",
         "Action":[
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:RevokeSecurityGroupIngress",
            "ec2:DeleteSecurityGroup"
         ],
         "Resource":"*",
         "Condition":{
            null:{
               "aws":"ResourceTag/elbv2.k8s.aws/cluster":"false"
            }
         }
      },
      {
         "Effect":"Allow",
         "Action":[
            "elasticloadbalancing:CreateLoadBalancer",
            "elasticloadbalancing:CreateTargetGroup"
         ],
         "Resource":"*",
         "Condition":{
            null:{
               "aws":"RequestTag/elbv2.k8s.aws/cluster":"false"
            }
         }
      },
      {
         "Effect":"Allow",
         "Action":[
            "elasticloadbalancing:CreateListener",
            "elasticloadbalancing:DeleteListener",
            "elasticloadbalancing:CreateRule",
            "elasticloadbalancing:DeleteRule"
         ],
         "Resource":"*"
      },
      {
         "Effect":"Allow",
         "Action":[
            "elasticloadbalancing:AddTags",
            "elasticloadbalancing:RemoveTags"
         ],
         "Resource":[
            "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
            "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
            "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
         ],
         "Condition":{
            null:{
               "aws":"RequestTag/elbv2.k8s.aws/cluster":"true",
               "aws":"ResourceTag/elbv2.k8s.aws/cluster":"false"
            }
         }
      },
      {
         "Effect":"Allow",
         "Action":[
            "elasticloadbalancing:AddTags",
            "elasticloadbalancing:RemoveTags"
         ],
         "Resource":[
            "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
            "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
            "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
            "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
         ]
      },
      {
         "Effect":"Allow",
         "Action":[
            "elasticloadbalancing:ModifyLoadBalancerAttributes",
            "elasticloadbalancing:SetIpAddressType",
            "elasticloadbalancing:SetSecurityGroups",
            "elasticloadbalancing:SetSubnets",
            "elasticloadbalancing:DeleteLoadBalancer",
            "elasticloadbalancing:ModifyTargetGroup",
            "elasticloadbalancing:ModifyTargetGroupAttributes",
            "elasticloadbalancing:DeleteTargetGroup"
         ],
         "Resource":"*",
         "Condition":{
            null:{
               "aws":"ResourceTag/elbv2.k8s.aws/cluster":"false"
            }
         }
      },
      {
         "Effect":"Allow",
         "Action":[
            "elasticloadbalancing:RegisterTargets",
            "elasticloadbalancing:DeregisterTargets"
         ],
         "Resource":"arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      },
      {
         "Effect":"Allow",
         "Action":[
            "elasticloadbalancing:SetWebAcl",
            "elasticloadbalancing:ModifyListener",
            "elasticloadbalancing:AddListenerCertificates",
            "elasticloadbalancing:RemoveListenerCertificates",
            "elasticloadbalancing:ModifyRule"
         ],
         "Resource":"*"
      }
   ]
}
EOM
  if ! gen3 awsrole info "$roleName" > /dev/null; then # setup role
    gen3_log_info "creating IAM role for ingress: $roleName, linking to sa $saName"
    gen3 awsrole create "$roleName" "$saName" || return 1
    aws iam put-role-policy --role-name "$roleName" --policy-document file://${ingressPolicy} --policy-name "$policyName" 1>&2
  else
    # update the annotation - just to be thorough
    gen3 awsrole sa-annotate "$saName" "$roleName"
  fi
  
  kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"

#----------------------------------------------------------------------------------------------------------


  
  if (! helm status aws-load-balancer-controller -n kube-system > /dev/null 2>&1 )  || [[ "$1" == "--force" ]]; then
    

    # Update this section to install aws-lb-controller :this: 
    helm repo add eks https://aws.github.io/eks-charts 2> >(grep -v 'This is insecure' >&2)
    helm repo update 2> >(grep -v 'This is insecure' >&2)
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=<cluster-name> --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller

    


    ## Install nginx-ingresss
    nginxValuesFile="${GEN3_HOME}/kube/services/ingress-controller/nginx-values.yaml"
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2> >(grep -v 'This is insecure' >&2)
    helm repo update 2> >(grep -v 'This is insecure' >&2)
    helm install nginx-ingress ingress-nginx/ingress-nginx  --namespace kube-system -f ${nginxValuesFile}
    # move to values.yaml
    # --set-string controller.service.externalTrafficPolicy=Local --set-string controller.service.type=NodePort --set controller.publishService.enabled=true --set serviceAccount.create=true --set rbac.create=true --set-string controller.config.server-tokens=false --set-string controller.config.use-proxy-protocol=false --set-string controller.config.compute-full-forwarded-for=true --set-string controller.config.use-forwarded-headers=true --set controller.metrics.enabled=true --set controller.autoscaling.maxReplicas=1 --set controller.autoscaling.minReplicas=1 --set controller.autoscaling.enabled=true
     
  else
    gen3_log_info "kube-setup-argo exiting - argo already deployed, use --force to redeploy"
  fi
else
  gen3_log_info "kube-setup-argo exiting - only deploys from default namespace"
fi
