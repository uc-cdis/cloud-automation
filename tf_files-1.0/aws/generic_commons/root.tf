terraform {
  backend "s3" {
    encrypt = "true"
    profile = "cdistest"
  }
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
    }
  }
}

provider "aws" {
  profile = "cdistest"
  region = var.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}


locals {
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Name         = var.vpc_name
    Organization = "Basic Services"
  }
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source = "terraform-aws-modules/eks/aws"

  cluster_name                   = var.vpc_name
  cluster_version                = var.eks_version
  cluster_endpoint_public_access = true

  cluster_addons = {
    kube-proxy = {}
    vpc-cni    = {}
    coredns = {
      configuration_values = jsonencode({
        computeType = "Fargate"
        # Ensure that we fully utilize the minimum amount of resources that are supplied by
        # Fargate https://docs.aws.amazon.com/eks/latest/userguide/fargate-pod-configuration.html
        # Fargate adds 256 MB to each pod's memory reservation for the required Kubernetes
        # components (kubelet, kube-proxy, and containerd). Fargate rounds up to the following
        # compute configuration that most closely matches the sum of vCPU and memory requests in
        # order to ensure pods always have the resources that they need to run.
        resources = {
          limits = {
            cpu = "0.25"
            # We are targeting the smallest Task size of 512Mb, so we subtract 256Mb from the
            # request/limit to ensure we can fit within that task
            memory = "256M"
          }
          requests = {
            cpu = "0.25"
            # We are targeting the smallest Task size of 512Mb, so we subtract 256Mb from the
            # request/limit to ensure we can fit within that task
            memory = "256M"
          }
        }
      })
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  # Fargate profiles use the cluster primary security group so these are not utilized
  create_cluster_security_group = false
  create_node_security_group    = false

  manage_aws_auth_configmap = true
  aws_auth_roles = [
    # We need to add in the Karpenter node IAM role for nodes launched by Karpenter
    {
      rolearn  = module.karpenter.role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    },
  ]

  fargate_profiles = {
    karpenter = {
      selectors = [
        { namespace = "karpenter" }
      ]
    }
    kube-system = {
      selectors = [
        { namespace = "kube-system" }
      ]
    }
  }

  tags = merge(local.tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = var.vpc_name
  })


}

################################################################################
# Karpenter
################################################################################

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name           = module.eks.cluster_name
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn

  policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "v0.21.1"

  set {
    name  = "settings.aws.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "settings.aws.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.irsa_arn
  }

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = module.karpenter.instance_profile_name
  }

  set {
    name  = "settings.aws.interruptionQueueName"
    value = module.karpenter.queue_name
  }
}

resource "kubectl_manifest" "karpenter_provisioner" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: default
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
      limits:
        resources:
          cpu: 1000
      providerRef:
        name: default
      ttlSecondsAfterEmpty: 30
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_template" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: default
    spec:
      subnetSelector:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

# Example deployment using the [pause image](https://www.ianlewis.org/en/almighty-pause-container)
# and starts with zero replicas
resource "kubectl_manifest" "karpenter_example_deployment" {
  yaml_body = <<-YAML
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: inflate
    spec:
      replicas: 0
      selector:
        matchLabels:
          app: inflate
      template:
        metadata:
          labels:
            app: inflate
        spec:
          terminationGracePeriodSeconds: 0
          containers:
            - name: inflate
              image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
              resources:
                requests:
                  cpu: 1
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs              = local.azs
  private_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 2, k)]
  public_subnets   = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 192)]
  intra_subnets    = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 195)]
  database_subnets = [cidrsubnet(var.vpc_cidr, 8, 198)]
  create_database_subnet_group  = false

  

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  database_subnet_tags = {
    "Name" = "private_db_alt"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    # Tags subnets for Karpenter auto-discovery
    "karpenter.sh/discovery" = var.vpc_name
  }

  tags = local.tags
}


resource "aws_db_subnet_group" "database" {
  name        = "${var.vpc_name}-subnet-group"
  description = "Database subnet group for ${var.vpc_name}"
  subnet_ids  = [ module.vpc.database_subnets[0], module.vpc.intra_subnets[0], module.vpc.intra_subnets[1] ]

  tags = local.tags
}


module "es" {
  source = "git::git@github.com:uc-cdis/cloud-automation.git//tf_files-1.0/aws/commons_vpc_es?ref=44404bf7b3a68c2eff31972a4de3b2d987d7a142"

  vpc_name = var.vpc_name
  es_linked_role = false
  depends_on = [
    module.vpc,
    aws_cloudwatch_log_group.main_log_group
  ]  
}

resource "aws_iam_user" "es_user" {
  name = "${var.vpc_name}_es_user"
  tags = {
    Environment  = "${var.vpc_name}"
    Organization = "Basic Services"
  }
}

resource "aws_iam_access_key" "es_user_key" {
  user = "${aws_iam_user.es_user.name}"
}

resource "aws_cloudwatch_log_group" "main_log_group" {
  name              = "${var.vpc_name}"
  retention_in_days = "1827"

  tags = {
    Environment  = "${var.vpc_name}"
    Organization = "Basic Services"
  }
}


module "aurora_postgresql_v2" {
  source = "terraform-aws-modules/rds-aurora/aws"

  name              = "${var.vpc_name}-postgres-cluster"
  engine            = data.aws_rds_engine_version.postgresql.engine
  engine_mode       = "provisioned"
  engine_version    = data.aws_rds_engine_version.postgresql.version
  storage_encrypted = true
  master_username   = "postgres"
  master_password   = random_password.master.result
  manage_master_user_password = false

  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = aws_db_subnet_group.database.name
  security_group_rules = {
    vpc_ingress = {
      cidr_blocks = module.vpc.private_subnets_cidr_blocks
    }
  }

  monitoring_interval = 60

  apply_immediately   = true
  skip_final_snapshot = true

  serverlessv2_scaling_configuration = {
    min_capacity = 1
    max_capacity = 10
  }

  instance_class = "db.serverless"
  instances = {
    one = {}
  }

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

resource "random_password" "master" {
  length  = 20
  special = false
}


resource "null_resource" "kubeconfig" {
  provisioner "local-exec" {
   command = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
  }
  depends_on = [ module.eks ]
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name               = "${var.vpc_name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_ingress_controller_assume_role.json
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${var.vpc_name}-aws-load-balancer-controller-policy"
  description = "Policy for AWS Load Balancer Controller"
  policy      = data.aws_iam_policy_document.aws_load_balancer_controller.json
}

resource "null_resource" "aws_load_balancer_controller" {
  provisioner "local-exec" {
    command = "kubectl apply -k \"github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master\" && kubectl create sa aws-load-balancer-controller -n kube-system && kubectl annotate sa -n kube-system aws-load-balancer-controller eks.amazonaws.com/role-arn=${aws_iam_role.aws_load_balancer_controller.arn}"
  }
  depends_on = [ 
    module.eks,
    aws_iam_role.aws_load_balancer_controller
  ]
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.5.2"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  depends_on = [ 
    module.eks,
    null_resource.aws_load_balancer_controller
  ]
}

module "gen3_deployment" {
  source = "../../gen3"

  aurora_password         = module.aurora_postgresql_v2.cluster_master_password
  aurora_hostname         = module.aurora_postgresql_v2.cluster_endpoint
  aurora_username         = "postgres"
  cluster_endpoint        = module.eks.cluster_endpoint
  cluster_ca_cert         = module.eks.cluster_certificate_authority_data
  cluster_name            = module.eks.cluster_name
  ambassador_enabled      = var.ambassador_enabled
  arborist_enabled        = var.arborist_enabled
  argo_enabled            = var.argo_enabled
  audit_enabled           = var.audit_enabled
  aws-es-proxy_enabled    = var.aws-es-proxy_enabled
  dbgap_enabled           = var.dbgap_enabled
  dd_enabled              = var.dd_enabled
  dictionary_url          = var.dictionary_url
  dispatcher_job_number   = var.dispatcher_job_number
  fence_enabled           = var.fence_enabled
  guppy_enabled           = var.guppy_enabled
  hatchery_enabled        = var.hatchery_enabled
  hostname                = var.hostname
  indexd_enabled          = var.indexd_enabled
  indexd_prefix           = var.indexd_prefix
  ingress_enabled         = var.ingress_enabled
  manifestservice_enabled = var.manifestservice_enabled
  metadata_enabled        = var.metadata_enabled
  netpolicy_enabled       = var.netpolicy_enabled
  peregrine_enabled       = var.peregrine_enabled
  pidgin_enabled          = var.pidgin_enabled
  portal_enabled          = var.portal_enabled
  public_datasets         = var.public_datasets
  requestor_enabled       = var.requestor_enabled
  revproxy_arn            = var.revproxy_arn
  revproxy_enabled        = var.revproxy_enabled
  sheepdog_enabled        = var.sheepdog_enabled
  slack_send_dbgap        = var.slack_send_dbgap
  slack_webhook           = var.slack_webhook
  ssjdispatcher_enabled   = var.ssjdispatcher_enabled
  tier_access_level       = var.tier_access_level
  tier_access_limit       = var.tier_access_limit
  usersync_enabled        = var.usersync_enabled
  usersync_schedule       = var.usersync_schedule
  useryaml_s3_path        = var.useryaml_s3_path
  wts_enabled             = var.wts_enabled
  fence_config_path       = var.fence_config_path
  useryaml_path           = var.useryaml_path
  gitops_path             = var.gitops_path
  google_client_id        = var.google_client_id
  google_client_secret    = var.google_client_secret
  fence_access_key        = var.fence_access_key
  fence_secret_key        = var.fence_secret_key
  upload_bucket           = var.upload_bucket
  namespace               = var.namespace
}
