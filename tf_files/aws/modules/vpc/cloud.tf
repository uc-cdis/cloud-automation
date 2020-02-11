#module "squid_proxy" {
#  source               = "../squid"
#  csoc_cidr            = "${var.peering_cidr}"
#  env_vpc_name         = "${var.vpc_name}"
#  env_public_subnet_id = "${aws_subnet.public.id}"
#  env_vpc_cidr         = "${aws_vpc.main.cidr_block}"
#  env_vpc_id           = "${aws_vpc.main.id}"
#  env_instance_profile = "${aws_iam_instance_profile.cluster_logging_cloudwatch.name}"
#  env_log_group        = "${aws_cloudwatch_log_group.main_log_group.name}"
#  ssh_key_name         = "${var.ssh_key_name}"
#}

/*
module "squid_auto" {
  source              = "../squid_auto"
  csoc_cidr            = "${var.peering_cidr}"
  env_vpc_name         = "${var.vpc_name}"
  env_public_subnet_id = "${aws_subnet.public.id}"
  env_vpc_cidr         = "${aws_vpc.main.cidr_block}"
  env_vpc_id           = "${aws_vpc.main.id}"
  env_instance_profile = "${aws_iam_instance_profile.cluster_logging_cloudwatch.name}"
  env_log_group        = "${aws_cloudwatch_log_group.main_log_group.name}"
  env_squid_name       = "${var.vpc_name}_squid_auto"
  squid_proxy_subnet   = "192.168.145.0/24"
  organization_name    = "${var.organization_name}"
  ssh_key_name         = "${var.ssh_key_name}"
   
  image_name_search_criteria = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"
}
*/
  
module "data-bucket" {
  source               = "../upload-data-bucket"
  vpc_name             = "${var.vpc_name}"
  cloudwatchlogs_group = "${aws_cloudwatch_log_group.main_log_group.arn}"
  environment          = "${var.vpc_name}"
}

module "fence-bot-user" {
  source               = "../fence-bot-user"
  vpc_name             = "${var.vpc_name}"
  bucket_name          = "${module.data-bucket.data-bucket_name}"
}

resource "aws_vpc" "main" {
  cidr_block           = "${var.vpc_cidr_block}"
  enable_dns_hostnames = true

  tags {
    Name         = "${var.vpc_name}"
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }

  lifecycle {
    ignore_changes = ["tags"]
  }
}

data "aws_vpc_endpoint_service" "s3" {
  service = "s3"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = "${aws_eip.nat_gw.id}"
  subnet_id     = "${aws_subnet.public.id}"

  tags {
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  route {
    #from the commons vpc to the csoc vpc via the peering connection
    cidr_block                = "${var.peering_cidr}"
    vpc_peering_connection_id = "${aws_vpc_peering_connection.vpcpeering.id}"
  }

  tags {
    Name         = "main"
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
}


resource "aws_eip" "nat_gw" {
  vpc = true
}


resource "aws_default_route_table" "default" {
  default_route_table_id = "${aws_vpc.main.default_route_table_id}"

  route {
    #from the commons vpc to the csoc vpc via the peering connection
    cidr_block                = "${var.peering_cidr}"
    vpc_peering_connection_id = "${aws_vpc_peering_connection.vpcpeering.id}"
  }

  tags {
    Name = "default table"
  }
}

resource "aws_main_route_table_association" "default" {
  vpc_id         = "${aws_vpc.main.id}"
  route_table_id = "${aws_default_route_table.default.id}"
}

resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public.id}"
}


resource "aws_subnet" "public" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "${cidrsubnet(var.vpc_cidr_block,4,0)}"
  map_public_ip_on_launch = true

  # kube_ subnets are in availability zone [0], so put this in [1]
  availability_zone = "${data.aws_availability_zones.available.names[1]}"

  tags = "${map("Name", "public", "Organization", var.organization_name, "Environment", var.vpc_name)}"

  lifecycle {
    # allow user to change tags interactively - ex - new kube-aws cluster
    ignore_changes = ["tags", "availability_zone"]
  }
}

#
# The need is to keep logs for no longer than 5 years so 
# we create the group before it is created automatically without 
# the retention period
#
resource "aws_cloudwatch_log_group" "main_log_group" {
  name              = "${var.vpc_name}"
  retention_in_days = "1827"

  tags {
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
}

#This needs vars from other branches, so hopefully will work just fine when they are merge
resource "aws_cloudwatch_log_subscription_filter" "csoc_subscription" {
  count             = "${var.csoc_managed == "yes" ? 1 : 0}"
  name              = "${var.vpc_name}_subscription"
  #destination_arn   = "arn:aws:logs:${data.aws_region.current.name}:${var.csoc_account_id}:destination:${var.vpc_name}_logs_destination"
  destination_arn   = "arn:aws:logs:${data.aws_region.current.name}:${var.csoc_managed == "yes" ? var.csoc_account_id : data.aws_caller_identity.current.account_id}:destination:${var.vpc_name}_logs_destination"
  log_group_name    = "${var.vpc_name}"
  filter_pattern    = ""
  lifecycle {
    # terraform keeps trying to remove the distribution even after it is properly set, there is no reason
    # to no to ignore this
    ignore_changes = ["distribution"]
  }
}

/*
data "aws_ami" "public_login_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu16-client-1.0.2-*"]
  }

  owners = ["${var.ami_account_id}"]
}
*/

#
# This AMI is no longer used here, but is referenced in 
# tf_files/aws/user-vpc and tf_files/aws/commons.
# It's handy to have the encrypted AMI ready to use in a VPC I think.
#
/*
resource "aws_ami_copy" "login_ami" {
  name              = "ub16-client-crypt-${var.vpc_name}-1.0.2"
  description       = "A copy of ubuntu16-client-1.0.2"
  source_ami_id     = "${data.aws_ami.public_login_ami.id}"
  source_ami_region = "us-east-1"
  encrypted         = true

  tags {
    Name = "login-${var.vpc_name}"
  }

  lifecycle {
    #
    # Do not force update when new ami becomes available.
    # We still need to improve our mechanism for tracking .ssh/authorized_keys
    # User can use 'terraform state taint' to trigger update.
    #
    ignore_changes = ["source_ami_id"]
  }
}
*/

/*
resource "aws_iam_role" "cluster_logging_cloudwatch" {
  name = "${var.vpc_name}_cluster_logging_cloudwatch"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

#
# This could go here or in the squid module. But squid may go away soon
# do not remove this
#
resource "aws_iam_role_policy" "cluster_logging_cloudwatch" {
  name   = "${var.vpc_name}_cluster_logging_cloudwatch"
  policy = "${data.aws_iam_policy_document.cluster_logging_cloudwatch.json}"
  role   = "${aws_iam_role.cluster_logging_cloudwatch.id}"
}

resource "aws_iam_instance_profile" "cluster_logging_cloudwatch" {
  name = "${var.vpc_name}_cluster_logging_cloudwatch"
  role = "${aws_iam_role.cluster_logging_cloudwatch.id}"
}
*/

resource "aws_route53_zone" "main" {
  name    = "internal.io"
  comment = "internal dns server for ${var.vpc_name}"
  vpc {
    vpc_id  = "${aws_vpc.main.id}"
  }
  
  tags {
    Environment  = "${var.vpc_name}"
    Organization = "${var.organization_name}"
  }
}

#resource "aws_route53_record" "squid" {
#  zone_id = "${aws_route53_zone.main.zone_id}"
#  name    = "cloud-proxy"
#  type    = "A"
#  ttl     = "300"
#  records = ["${module.squid_proxy.squid_private_ip}"]
#}

# this is for vpc peering
resource "aws_vpc_peering_connection" "vpcpeering" {
  peer_owner_id = "${var.csoc_managed == "yes" ? var.csoc_account_id : data.aws_caller_identity.current.account_id}"
  peer_vpc_id   = "${var.csoc_vpc_id}"
  vpc_id        = "${aws_vpc.main.id}"
  auto_accept   = true

  tags {
    Name = "VPC Peering between ${var.vpc_name} and csoc_main_vpc"
  }
}



# If this is an independent commons, then we should add the route on the VPC where the adminVM is, because we can

data "aws_route_tables" "control_routing_table" {
  count = "${var.csoc_managed == "yes" ? 0 : 1}"
  vpc_id = "${var.csoc_vpc_id}"

  # If we wanted to filter by tags later we could
#  filter {
#    name   = "tag:kubernetes.io/kops/role"
#    values = ["private*"]
#  }
}


resource "aws_route" "default_csoc" {
  count = "${var.csoc_managed == "yes" ? 0 : 1}"
  route_table_id            = "${data.aws_route_tables.control_routing_table.ids[count.index]}"
  destination_cidr_block    = "${var.vpc_cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.vpcpeering.id}"
}

##to be used by arranger when accessing the ES
resource "aws_iam_user" "es_user" {
  name = "${var.vpc_name}_es_user"
}

resource "aws_iam_access_key" "es_user_key" {
  user = "${aws_iam_user.es_user.name}"
}


