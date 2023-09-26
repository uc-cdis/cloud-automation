module "squid-auto" {
  source                         = "../squid_auto"
  peering_cidr                   = var.peering_cidr
  secondary_cidr_block           = var.secondary_cidr_block
  env_vpc_name                   = var.vpc_name
  env_vpc_cidr                   = aws_vpc.main.cidr_block
  env_vpc_id                     = aws_vpc.main.id
  env_log_group                  = aws_cloudwatch_log_group.main_log_group.name
  env_squid_name                 = "squid-auto-${var.vpc_name}"
  squid_proxy_subnet             = var.network_expansion ? cidrsubnet(var.vpc_cidr_block,5,3) : cidrsubnet(var.vpc_cidr_block,4,1)
  organization_name              = var.organization_name
  ssh_key_name                   = var.ssh_key_name
  ami_account_id                 = var.ami_account_id
  image_name_search_criteria     = var.squid_image_search_criteria
  squid_instance_drive_size      = var.squid_instance_drive_size
  squid_availability_zones       = var.availability_zones
  main_public_route              = aws_route_table.public.id
  route_53_zone_id               = aws_route53_zone.main.id
  squid_instance_type            = var.squid_instance_type
  bootstrap_script               = var.squid_bootstrap_script
  extra_vars                     = var.squid_extra_vars
  branch                         = var.branch
  cluster_max_size               = var.squid_cluster_max_size
  cluster_min_size               = var.squid_cluster_min_size
  cluster_desired_capasity       = var.squid_cluster_desired_capasity
  network_expansion              = var.network_expansion
  squid_depends_on               = aws_nat_gateway.nat_gw.id
  activation_id                  = var.activation_id
  customer_id                    = var.customer_id
  slack_webhook                  = var.slack_webhook
  fips                           = var.fips
}

module "data-bucket" {
  source               = "../upload-data-bucket"
  vpc_name             = var.vpc_name
  cloudwatchlogs_group = aws_cloudwatch_log_group.main_log_group.arn
  environment          = var.vpc_name
  deploy_cloud_trail   = var.deploy_cloud_trail
}

module "fence-bot-user" {
  source               = "../fence-bot-user"
  vpc_name             = var.vpc_name
  bucket_name          = module.data-bucket.data-bucket_name
  bucket_access_arns   = var.fence-bot_bucket_access_arns
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true

  tags = {
    Name         = var.vpc_name
    Environment  = var.vpc_name
    Organization = var.organization_name
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_flow_log" "main" {
  count           = var.vpc_flow_logs ? 1 : 0
  iam_role_arn    = aws_iam_role.flow_logs[count.index].arn
  log_destination = aws_cloudwatch_log_group.main_log_group.arn
  traffic_type    = var.vpc_flow_traffic
  vpc_id          = aws_vpc.main.id
}

resource "aws_iam_role" "flow_logs" {
  count              = var.vpc_flow_logs ? 1 : 0
  name               = "${var.vpc_name}_flow_logs_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "example" {
  count  = var.vpc_flow_logs ? 1 : 0
  name   = "${var.vpc_name}_flow_logs_policy"
  role   = aws_iam_role.flow_logs[count.index].id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}



resource "aws_vpc_ipv4_cidr_block_association" "secondary_cidr" {
  count      = var.secondary_cidr_block != "" ? 1 : 0
  vpc_id     = aws_vpc.main.id
  cidr_block = var.secondary_cidr_block
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name         = "${var.vpc_name}-igw"
    Environment  = var.vpc_name
    Organization = var.organization_name
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_gw.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name         = "${var.vpc_name}-ngw"
    Environment  = var.vpc_name
    Organization = var.organization_name
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    #from the commons vpc to the csoc vpc via the peering connection
    cidr_block                = var.peering_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.vpcpeering.id
  }

  tags = {
    Name         = "main"
    Environment  = var.vpc_name
    Organization = var.organization_name
  }

  lifecycle {
    # ignore changes
    ignore_changes = all
  }
}


resource "aws_eip" "nat_gw" {
  vpc = true

  tags = {
    Name         = "${var.vpc_name}-ngw-eip"
    Environment  = var.vpc_name
    Organization = var.organization_name
  }
}


resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  route {
    #from the commons vpc to the csoc vpc via the peering connection
    cidr_block                = var.peering_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.vpcpeering.id
  }

  tags = {
    Name         = "default table"
    Environment  = var.vpc_name
    Organization = var.organization_name
  }
}

resource "aws_main_route_table_association" "default" {
  vpc_id         = aws_vpc.main.id
  route_table_id = aws_default_route_table.default.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}


resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.network_expansion ? cidrsubnet(var.vpc_cidr_block,5,2) : cidrsubnet(var.vpc_cidr_block,4,0)
  map_public_ip_on_launch = true
  # kube_ subnets are in availability zone [0], so put this in [1]
  availability_zone       = data.aws_availability_zones.available.names[1]
  tags                    = tomap({"Name" = "public", "Organization" = var.organization_name, "Environment" = var.vpc_name})

  lifecycle {
    # allow user to change tags interactively - ex - new kube-aws cluster
    ignore_changes = [tags, availability_zone]
  }
}

#
# The need is to keep logs for no longer than 5 years so 
# we create the group before it is created automatically without 
# the retention period
#
resource "aws_cloudwatch_log_group" "main_log_group" {
  name              = var.vpc_name
  retention_in_days = var.commons_log_retention

  tags = {
    Environment  = var.vpc_name
    Organization = var.organization_name
  }
}

#This needs vars from other branches, so hopefully will work just fine when they are merge
resource "aws_cloudwatch_log_subscription_filter" "csoc_subscription" {
  count             = "${var.csoc_managed && var.send_logs_to_csoc ? 1 : 0}"
  name              = "${var.vpc_name}_subscription"
  destination_arn   = "arn:aws:logs:${data.aws_region.current.name}:${var.csoc_managed ? var.csoc_account_id : data.aws_caller_identity.current.account_id}:destination:${var.vpc_name}_logs_destination"
  log_group_name    = var.vpc_name
  filter_pattern    = ""

  lifecycle {
    # terraform keeps trying to remove the distribution even after it is properly set, there is no reason
    # to no to ignore this
    ignore_changes = [distribution]
  }
}

resource "aws_route53_zone" "main" {
  name    = "internal.io"
  comment = "internal dns server for ${var.vpc_name}"

  vpc {
    vpc_id  = aws_vpc.main.id
  }
  
  tags = {
    Environment  = var.vpc_name
    Organization = var.organization_name
  }
}

# this is for vpc peering
resource "aws_vpc_peering_connection" "vpcpeering" {
  peer_owner_id = var.csoc_managed ? var.csoc_account_id : data.aws_caller_identity.current.account_id
  peer_vpc_id   = var.peering_vpc_id
  vpc_id        = aws_vpc.main.id
  auto_accept   = false

  tags = {
    Name         = "VPC Peering between ${var.vpc_name} and adminVM vpc"
    Environment  = var.vpc_name
    Organization = var.organization_name
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "aws_route" "default_csoc" {
  count                     = var.csoc_managed ? 0 : 1
  route_table_id            = data.aws_route_tables.control_routing_table[count.index].id
  destination_cidr_block    = var.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpcpeering.id
}

##to be used by arranger when accessing the ES
resource "aws_iam_user" "es_user" {
  name = "${var.vpc_name}_es_user"

  tags = {
    Environment  = var.vpc_name
    Organization = var.organization_name
  }
}

resource "aws_iam_access_key" "es_user_key" {
  user = aws_iam_user.es_user.name
}
