data "aws_availability_zones" "available" {
}

data "aws_iam_policy_document" "kube_provisioner" {
    statement {
      effect = "Allow"
      actions = [
          "acm:*",
      ]
      resources = [ "*" ]
    }
    
    statement {
      effect = "Allow"
      actions = [
        "route53:*",
        "route53domains:*",
        "cloudfront:ListDistributions",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticbeanstalk:DescribeEnvironments",
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:GetBucketWebsite",
        "ec2:DescribeVpcs",
        "ec2:DescribeRegions",
        "sns:ListTopics",
        "sns:ListSubscriptionsByTopic",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:GetMetricStatistics",
      ]
      resources = [ "*" ]
    }
    
    statement {
      effect = "Allow"
      actions = [
        "kms:CreateAlias",
        "kms:CreateKey",
        "kms:DeleteAlias",
        "kms:Describe*",
        "kms:GenerateRandom",
        "kms:Get*",
        "kms:List*",
        "kms:TagResource",
        "kms:UntagResource",
        "iam:ListGroups",
        "iam:ListRoles",
        "iam:ListUsers",
      ]
      resources = [ "*" ]
    }
    
    statement {
      effect = "Allow"
      actions = [
          "ec2:AcceptVpcPeeringConnection",
          "ec2:AllocateAddress",
          "ec2:AssignPrivateIpAddresses",
          "ec2:AssociateAddress",
          "ec2:AssociateDhcpOptions",
          "ec2:AssociateRouteTable",
          "ec2:AttachClassicLinkVpc",
          "ec2:AttachInternetGateway",
          "ec2:AttachNetworkInterface",
          "ec2:AttachVpnGateway",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:CreateCustomerGateway",
          "ec2:CreateDhcpOptions",
          "ec2:CreateFlowLogs",
          "ec2:CreateInternetGateway",
          "ec2:CreateNatGateway",
          "ec2:CreateNetworkAcl",
          "ec2:CreateNetworkAcl",
          "ec2:CreateNetworkAclEntry",
          "ec2:CreateNetworkInterface",
          "ec2:CreateRoute",
          "ec2:CreateRouteTable",
          "ec2:CreateSecurityGroup",
          "ec2:CreateSubnet",
          "ec2:CreateTags",
          "ec2:CreateVpc",
          "ec2:CreateVpcEndpoint",
          "ec2:CreateVpcPeeringConnection",
          "ec2:CreateVpnConnection",
          "ec2:CreateVpnConnectionRoute",
          "ec2:CreateVpnGateway",
          "ec2:DeleteCustomerGateway",
          "ec2:DeleteDhcpOptions",
          "ec2:DeleteFlowLogs",
          "ec2:DeleteInternetGateway",
          "ec2:DeleteNatGateway",
          "ec2:DeleteNetworkAcl",
          "ec2:DeleteNetworkAclEntry",
          "ec2:DeleteNetworkInterface",
          "ec2:DeleteRoute",
          "ec2:DeleteRouteTable",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteSubnet",
          "ec2:DeleteTags",
          "ec2:DeleteVpc",
          "ec2:DeleteVpcEndpoints",
          "ec2:DeleteVpcPeeringConnection",
          "ec2:DeleteVpnConnection",
          "ec2:DeleteVpnConnectionRoute",
          "ec2:DeleteVpnGateway",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeClassicLinkInstances",
          "ec2:DescribeCustomerGateways",
          "ec2:DescribeDhcpOptions",
          "ec2:DescribeFlowLogs",
          "ec2:DescribeInstances",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeMovingAddresses",
          "ec2:DescribeNatGateways",
          "ec2:DescribeNetworkAcls",
          "ec2:DescribeNetworkInterfaceAttribute",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribePrefixLists",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeTags",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeVpcClassicLink",
          "ec2:DescribeVpcEndpoints",
          "ec2:DescribeVpcEndpointServices",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpnConnections",
          "ec2:DescribeVpnGateways",
          "ec2:DetachClassicLinkVpc",
          "ec2:DetachInternetGateway",
          "ec2:DetachNetworkInterface",
          "ec2:DetachVpnGateway",
          "ec2:DisableVgwRoutePropagation",
          "ec2:DisableVpcClassicLink",
          "ec2:DisassociateAddress",
          "ec2:DisassociateRouteTable",
          "ec2:EnableVgwRoutePropagation",
          "ec2:EnableVpcClassicLink",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:ModifySubnetAttribute",
          "ec2:ModifyVpcAttribute",
          "ec2:ModifyVpcEndpoint",
          "ec2:MoveAddressToVpc",
          "ec2:RejectVpcPeeringConnection",
          "ec2:ReleaseAddress",
          "ec2:ReplaceNetworkAclAssociation",
          "ec2:ReplaceNetworkAclEntry",
          "ec2:ReplaceRoute",
          "ec2:ReplaceRouteTableAssociation",
          "ec2:ResetNetworkInterfaceAttribute",
          "ec2:RestoreAddressToClassic",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:UnassignPrivateIpAddresses",
      ]
      resources = [ "*" ]
    }

    statement {
      effect = "Allow"
      actions = [ "s3:*" ]
      resources = [ "*" ]
    }

    statement {
      effect = "Allow"
      actions = [
          "ecr:*",
          "cloudtrail:LookupEvents"
      ],
      resources = [ "*" ]
    }

    statement {
      actions = [ "ec2:*" ]
      effect = "Allow"
      resources = [ "*" ]
    }

    statement {
      effect = "Allow"
      actions = [ "elasticloadbalancing:*" ]
      resources = [ "*" ]
    }

    statement {
      effect = "Allow"
      actions = [ "cloudwatch:*" ]
      resources = [ "*" ]
    }

    statement {
      effect = "Allow"
      actions = [ "autoscaling:*" ]
      resources = [ "*" ]
    }

    statement {
        effect = "Allow"
        actions = [ "iam:CreateServiceLinkedRole" ]
        resources = [ "arn:aws:iam::*:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot*" ]
        condition = {
          test = "StringLike"
          variable = "iam:AWSServiceName"
          values = [ "spot.amazonaws.com" ]
        }
    }

    statement {
        effect = "Allow"
        actions = [ "iam:CreateServiceLinkedRole" ]
        resources = [ "arn:aws:iam::*:role/aws-service-role/spotfleet.amazonaws.com/AWSServiceRoleForEC2Spot*" ]
        condition = {
          test = "StringLike"
          variable = "iam:AWSServiceName"
          values = [ "spotfleet.amazonaws.com" ]
        }
    }
    
    statement {
        effect = "Allow"
        actions = [ "iam:CreateServiceLinkedRole" ]
        resources = [ "arn:aws:iam::*:role/aws-service-role/ec2scheduled.amazonaws.com/AWSServiceRoleForEC2Scheduled*" ]
        condition = {
          test = "StringLike"
          variable = "iam:AWSServiceName"
          values = [ "ec2scheduled.amazonaws.com" ]
        }
    }
    
    statement {
        actions = [
            "rds:*",
            "cloudwatch:DescribeAlarms",
            "cloudwatch:GetMetricStatistics",
            "ec2:DescribeAccountAttributes",
            "ec2:DescribeAvailabilityZones",
            "ec2:DescribeInternetGateways",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeSubnets",
            "ec2:DescribeVpcAttribute",
            "ec2:DescribeVpcs",
            "sns:ListSubscriptions",
            "sns:ListTopics",
            "sns:Publish",
            "logs:DescribeLogStreams",
            "logs:GetLogEvents",
        ]
        effect = "Allow"
        resources = [ "*" ]
    }

    statement {
        actions = [ "pi:*" ]
        effect = "Allow"
        resources = [ "arn:aws:pi:*:*:metrics/rds/*" ]
    }

    statement {
        actions = [ "iam:CreateServiceLinkedRole" ]
        effect = "Allow"
        resources = [ "arn:aws:iam::*:role/aws-service-role/rds.amazonaws.com/AWSServiceRoleForRDS" ]
        condition = {
          test = "StringLike"
          variable = "iam:AWSServiceName"
          values = [ "rds.amazonaws.com" ]
        }
    }

    statement {
      effect = "Allow"
      actions = [ "iam:*" ]
      resources = [ "*" ]
    }
    
}