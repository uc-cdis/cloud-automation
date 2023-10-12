locals {
  account_id = data.aws_caller_identity.current.account_id
}

################################################################################
# IAM Role for Service Account (IRSA)
# This is used by the Karpenter controller
################################################################################

locals {
  create_irsa      = true
  irsa_name        = "${var.vpc_name}-karpenter-sa"
  irsa_policy_name = local.irsa_name

  irsa_oidc_provider_url = replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")
}

data "aws_iam_policy_document" "irsa_assume_role" {
  count = var.use_karpenter ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${local.account_id}:oidc-provider/${local.irsa_oidc_provider_url}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.irsa_oidc_provider_url}:sub"
      values   = ["system:serviceaccount:karpenter:karpenter"]
    }

    # https://aws.amazon.com/premiumsupport/knowledge-center/eks-troubleshoot-oidc-and-irsa/?nc1=h_ls
    condition {
      test     = "StringEquals"
      variable = "${local.irsa_oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "irsa" {
  count = var.use_karpenter ? 1 : 0

  name        = local.irsa_name

  assume_role_policy    = data.aws_iam_policy_document.irsa_assume_role[0].json
  force_detach_policies = true
}

locals {
  irsa_tag_values = [aws_eks_cluster.eks_cluster.id]
}

data "aws_iam_policy_document" "irsa" {
  count = var.use_karpenter ? 1 : 0

  statement {
    actions = [
      "ec2:CreateLaunchTemplate",
      "ec2:CreateFleet",
      "ec2:CreateTags",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeSpotPriceHistory",
      "iam:PassRole",
      "pricing:GetProducts",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "ec2:TerminateInstances",
      "ec2:DeleteLaunchTemplate",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/Name"
      values   = ["*karpenter*"]
    }
  }

  statement {
    actions = ["ec2:RunInstances"]
    resources = [
      "arn:aws:ec2:*:${local.account_id}:launch-template/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/Name"
      values   = ["*karpenter*"]
    }
  }

  statement {
    actions = ["ec2:RunInstances"]
    resources = [
      "arn:aws:ec2:*::image/*",
      "arn:aws:ec2:*::snapshot/*",
      "arn:aws:ec2:*:${local.account_id}:instance/*",
      "arn:aws:ec2:*:${local.account_id}:spot-instances-request/*",
      "arn:aws:ec2:*:${local.account_id}:security-group/*",
      "arn:aws:ec2:*:${local.account_id}:volume/*",
      "arn:aws:ec2:*:${local.account_id}:network-interface/*",
      "arn:aws:ec2:*:${local.account_id}:subnet/*",
    ]
  }

  statement {
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:*:*:parameter/aws/service/*"]
  }

  statement {
    actions   = ["eks:DescribeCluster"]
    resources = ["arn:aws:eks:*:${local.account_id}:cluster/${aws_eks_cluster.eks_cluster.id}"]
  }

  statement {
      actions = [
        "sqs:DeleteMessage",
        "sqs:GetQueueUrl",
        "sqs:GetQueueAttributes",
        "sqs:ReceiveMessage",
      ]
      resources = [aws_sqs_queue.this[0].arn]
  }
}

resource "aws_iam_policy" "irsa" {
  count = var.use_karpenter ? 1 : 0

  name        = "${local.irsa_policy_name}-policy"
  policy      = data.aws_iam_policy_document.irsa[0].json
}

resource "aws_iam_role_policy_attachment" "irsa" {
  count = var.use_karpenter ? 1 : 0

  role       = aws_iam_role.irsa[0].name
  policy_arn = aws_iam_policy.irsa[0].arn
}


################################################################################
# Node Termination Queue
################################################################################

locals {
  enable_spot_termination = true
  queue_name = "${var.vpc_name}-${aws_eks_cluster.eks_cluster.id}"
}

resource "aws_sqs_queue" "this" {
  count = var.use_karpenter ? 1 : 0

  name                              = local.queue_name
  message_retention_seconds         = 300
}

data "aws_iam_policy_document" "queue" {
  count = var.use_karpenter ? 1 : 0

  statement {
    sid       = "SqsWrite"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.this[0].arn]

    principals {
      type = "Service"
      identifiers = [
        "events.amazonaws.com",
        "sqs.amazonaws.com",
      ]
    }

  }
}

resource "aws_sqs_queue_policy" "this" {
  count = var.use_karpenter ? 1 : 0

  queue_url = aws_sqs_queue.this[0].url
  policy    = data.aws_iam_policy_document.queue[0].json
}

################################################################################
# Node Termination Event Rules
################################################################################

locals {
  events = {
    health_event = {
      name        = "HealthEvent"
      description = "Karpenter interrupt - AWS health event"
      event_pattern = {
        source      = ["aws.health"]
        detail-type = ["AWS Health Event"]
      }
    }
    spot_interupt = {
      name        = "SpotInterrupt"
      description = "Karpenter interrupt - EC2 spot instance interruption warning"
      event_pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Spot Instance Interruption Warning"]
      }
    }
    instance_rebalance = {
      name        = "InstanceRebalance"
      description = "Karpenter interrupt - EC2 instance rebalance recommendation"
      event_pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance Rebalance Recommendation"]
      }
    }
    instance_state_change = {
      name        = "InstanceStateChange"
      description = "Karpenter interrupt - EC2 instance state-change notification"
      event_pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance State-change Notification"]
      }
    }
  }
}

resource "aws_cloudwatch_event_rule" "this" {
  for_each = { for k, v in local.events : k => v if var.use_karpenter }

  name_prefix   = "${var.vpc_name}-${each.value.name}-"
  description   = each.value.description
  event_pattern = jsonencode(each.value.event_pattern)

  tags = { 
    ClusterName = aws_eks_cluster.eks_cluster.id 
  }
}

resource "aws_cloudwatch_event_target" "this" {
  for_each = { for k, v in local.events : k => v if var.use_karpenter }

  rule      = aws_cloudwatch_event_rule.this[each.key].name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.this[0].arn
}








resource "aws_eks_fargate_profile" "karpenter" {
  count                  = var.use_karpenter ? 1 : 0
  cluster_name           = aws_eks_cluster.eks_cluster.name
  fargate_profile_name   = "karpenter"
  pod_execution_role_arn = aws_iam_role.karpenter.0.arn
  subnet_ids             = local.eks_priv_subnets

  selector {
    namespace = "karpenter"
  }
}

resource "time_sleep" "wait_60_seconds" {
  create_duration = "60s"

  depends_on = [aws_eks_fargate_profile.karpenter]
}

resource "aws_iam_role" "karpenter" {
  count = var.use_karpenter ? 1 : 0
  name  = "${var.vpc_name}-karpenter-fargate-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "karpenter-role-policy" {
  count      = var.use_karpenter ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.karpenter.0.name
}

resource "helm_release" "karpenter" {
  count               = var.use_karpenter ? 1 : 0
  namespace           = "karpenter"
  create_namespace    = true
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = var.karpenter_version

  set {
    name  = "settings.aws.clusterName"
    value = aws_eks_cluster.eks_cluster.id
  }

  set {
    name  = "settings.aws.clusterEndpoint"
    value = aws_eks_cluster.eks_cluster.endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.irsa[0].arn
  }

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = aws_iam_instance_profile.eks_node_instance_profile.id
  }

  set {
    name  = "settings.aws.interruptionQueueName"
    value = aws_sqs_queue.this[0].name
  }

  depends_on = [time_sleep.wait_60_seconds]
}

resource "kubectl_manifest" "karpenter_provisioner" {
  count   = var.use_karpenter ? 1 : 0

  yaml_body = <<-YAML
    ---
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: default
    spec:
      # Allow for spot and on demand instances
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand", "spot"]
        - key: kubernetes.io/arch
          operator: In
          values:
          - amd64
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values:
          - c
          - m
          - r
          - t       
      # Set a limit of 1000 vcpus
      limits:
        resources:
          cpu: 1000
      # Use the default node template
      providerRef:
        name: default
      # Allow pods to be rearranged
      consolidation:
        enabled: true
      # Kill nodes after 30 days to ensure they stay up to date
      ttlSecondsUntilExpired: 2592000
    ---
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: jupyter
    spec:
      # Only allow on demand instance        
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: kubernetes.io/arch
          operator: In
          values:
          - amd64
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values:
          - c
          - m
          - r
          - t       
      # Set a taint for jupyter pods
      taints:
        - key: role
          value: jupyter
          effect: NoSchedule       
      labels:
        role: jupyter
      # Set a limit of 1000 vcpus      
      limits:
        resources:
          cpu: 1000
      # Use the jupyter node template      
      providerRef:
        name: jupyter
      # Allow pods to be rearranged
      consolidation:
        enabled: true
      # Kill nodes after 30 days to ensure they stay up to date
      ttlSecondsUntilExpired: 2592000
    ---
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: workflow
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: kubernetes.io/arch
          operator: In
          values:
          - amd64
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values:
          - c
          - m
          - r
          - t       
      taints:
        - key: role
          value: workflow
          effect: NoSchedule
      labels:
        role: workflow
      limits:
        resources:
          cpu: 1000
      providerRef:
        name: workflow
      # Allow pods to be rearranged
      consolidation:
        enabled: true
      # Kill nodes after 30 days to ensure they stay up to date
      ttlSecondsUntilExpired: 2592000    
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_template" {
  count   = var.use_karpenter ? 1 : 0

  yaml_body = <<-YAML
    ---
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: default
    spec:
      subnetSelector:
        karpenter.sh/discovery: ${var.vpc_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${var.vpc_name}
      tags:
        karpenter.sh/discovery: ${var.vpc_name}
        Environment: ${var.vpc_name}
        Name: eks-${var.vpc_name}-karpenter
      metadataOptions:
        httpEndpoint: enabled
        httpProtocolIPv6: disabled
        httpPutResponseHopLimit: 2
        httpTokens: optional
      userData: |
        MIME-Version: 1.0
        Content-Type: multipart/mixed; boundary="BOUNDARY"

        --BOUNDARY
        Content-Type: text/x-shellscript; charset="us-ascii"

        #!/bin/bash -xe
        instanceId=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .instanceId)
        curl https://raw.githubusercontent.com/uc-cdis/cloud-automation/master/files/authorized_keys/ops_team >> /home/ec2-user/.ssh/authorized_keys
        aws ec2 create-tags --resources $instanceId --tags 'Key="instanceId",Value='$instanceId''
        curl https://raw.githubusercontent.com/uc-cdis/cloud-automation/master/files/authorized_keys/ops_team >> /home/ec2-user/.ssh/authorized_keys

        sysctl -w fs.inotify.max_user_watches=12000

        sudo yum update -y
        sudo yum install -y dracut-fips openssl >> /opt/fips-install.log
        sudo  dracut -f
        # configure grub
        sudo /sbin/grubby --update-kernel=ALL --args="fips=1"

        --BOUNDARY
        Content-Type: text/cloud-config; charset="us-ascii"

        power_state:
          delay: now
          mode: reboot
          message: Powering off
          timeout: 2
          condition: true


        --BOUNDARY--
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: ${var.worker_drive_size}Gi
            volumeType: gp2
            encrypted: true
            deleteOnTermination: true
    ---
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: jupyter
    spec:
      subnetSelector:
        karpenter.sh/discovery: ${var.vpc_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${var.vpc_name}
      tags:
        Environment: ${var.vpc_name}
        Name: eks-${var.vpc_name}-jupyter-karpenter
        karpenter.sh/discovery: ${var.vpc_name}
      metadataOptions:
        httpEndpoint: enabled
        httpProtocolIPv6: disabled
        httpPutResponseHopLimit: 2
        httpTokens: optional
      userData: |
        MIME-Version: 1.0
        Content-Type: multipart/mixed; boundary="BOUNDARY"

        --BOUNDARY
        Content-Type: text/x-shellscript; charset="us-ascii"

        #!/bin/bash -xe
        instanceId=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .instanceId)
        curl https://raw.githubusercontent.com/uc-cdis/cloud-automation/master/files/authorized_keys/ops_team >> /home/ec2-user/.ssh/authorized_keys
        aws ec2 create-tags --resources $instanceId --tags 'Key="instanceId",Value='$instanceId''
        curl https://raw.githubusercontent.com/uc-cdis/cloud-automation/master/files/authorized_keys/ops_team >> /home/ec2-user/.ssh/authorized_keys

        sysctl -w fs.inotify.max_user_watches=12000

        sudo yum update -y
        sudo yum install -y dracut-fips openssl >> /opt/fips-install.log
        sudo  dracut -f
        # configure grub
        sudo /sbin/grubby --update-kernel=ALL --args="fips=1"

        --BOUNDARY
        Content-Type: text/cloud-config; charset="us-ascii"

        power_state:
          delay: now
          mode: reboot
          message: Powering off
          timeout: 2
          condition: true

        --BOUNDARY--
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: ${var.jupyter_worker_drive_size}Gi
            volumeType: gp2
            encrypted: true
            deleteOnTermination: true 
    ---
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: workflow
    spec:
      subnetSelector:
        karpenter.sh/discovery: ${var.vpc_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${var.vpc_name}
      tags:
        Environment: ${var.vpc_name}
        Name: eks-${var.vpc_name}-workflow-karpenter
        karpenter.sh/discovery: ${var.vpc_name}
      metadataOptions:
        httpEndpoint: enabled
        httpProtocolIPv6: disabled
        httpPutResponseHopLimit: 2
        httpTokens: optional
      userData: |
        MIME-Version: 1.0
        Content-Type: multipart/mixed; boundary="BOUNDARY"

        --BOUNDARY
        Content-Type: text/x-shellscript; charset="us-ascii"

        #!/bin/bash -xe
        instanceId=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .instanceId)
        curl https://raw.githubusercontent.com/uc-cdis/cloud-automation/master/files/authorized_keys/ops_team >> /home/ec2-user/.ssh/authorized_keys
        aws ec2 create-tags --resources $instanceId --tags 'Key="instanceId",Value='$instanceId''
        curl https://raw.githubusercontent.com/uc-cdis/cloud-automation/master/files/authorized_keys/ops_team >> /home/ec2-user/.ssh/authorized_keys

        sysctl -w fs.inotify.max_user_watches=12000

        sudo yum update -y
        sudo yum install -y dracut-fips openssl >> /opt/fips-install.log
        sudo  dracut -f
        # configure grub
        sudo /sbin/grubby --update-kernel=ALL --args="fips=1"

        --BOUNDARY
        Content-Type: text/cloud-config; charset="us-ascii"

        power_state:
          delay: now
          mode: reboot
          message: Powering off
          timeout: 2
          condition: true

        --BOUNDARY--
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: ${var.workflow_worker_drive_size}Gi
            volumeType: gp2
            encrypted: true
            deleteOnTermination: true     
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}
