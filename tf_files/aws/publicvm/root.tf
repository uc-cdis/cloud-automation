terraform {
  backend "s3" {
    encrypt = "true"
  }
}

locals {
  fips_endpoints =  {
    acm = "${var.fips ? "https://acm-fips.us-east-1.amazonaws.com" : ""}"
    acmpca = "${var.fips ? "https://acm-pca-fips.us-east-1.amazonaws.com" : ""}"
    apigateway = "${var.fips ? "https://apigateway-fips.us-east-1.amazonaws.com" : ""}"
    appstream = "${var.fips ? "https://appstream2-fips.us-east-1.amazonaws.com" : ""}"
    cloudformation = "${var.fips ? "https://cloudformation-fips.us-east-1.amazonaws.com" : ""}"
    cloudfront = "${var.fips ? "https://cloudfront-fips.amazonaws.com" : ""}"
    cloudtrail = "${var.fips ? "https://cloudtrail-fips.us-east-1.amazonaws.com" : ""}"
    codebuild = "${var.fips ? "https://codebuild-fips.us-east-1.amazonaws.com" : ""}"
    codecommit = "${var.fips ? "https://codecommit-fips.us-east-1.amazonaws.com" : ""}"
    codedeploy = "${var.fips ? "https://codedeploy-fips.us-east-1.amazonaws.com" : ""}"
    cognitoidentity = "${var.fips ? "https://cognito-identity-fips.us-east-1.amazonaws.com" : ""}"
    cognitoidp = "${var.fips ? "https://cognito-idp-fips.us-east-1.amazonaws.com" : ""}"
    configservice = "${var.fips ? "https://config-fips.us-east-1.amazonaws.com" : ""}"
    datasync = "${var.fips ? "https://datasync-fips.us-east-1.amazonaws.com" : ""}"
    directconnect = "${var.fips ? "https://directconnect-fips.us-east-1.amazonaws.com" : ""}"
    dms = "${var.fips ? "https://dms-fips.us-east-1.amazonaws.com" : ""}"
    ds = "${var.fips ? "https://ds-fips.us-east-1.amazonaws.com" : ""}"
    dynamodb = "${var.fips ? "https://dynamodb-fips.us-east-1.amazonaws.com" : ""}"
    ec2 = "${var.fips ? "https://ec2-fips.us-east-1.amazonaws.com" : ""}"
    ecr = "${var.fips ? "https://ecr-fips.us-east-1.amazonaws.com" : ""}"
    elasticache = "${var.fips ? "https://elasticache-fips.us-east-1.amazonaws.com" : ""}"
    elasticbeanstalk = "${var.fips ? "https://elasticbeanstalk-fips.us-east-1.amazonaws.com" : ""}"
    elb = "${var.fips ? "https://elasticloadbalancing-fips.us-east-1.amazonaws.com" : ""}"
    emr = "${var.fips ? "https://elasticmapreduce-fips.us-east-1.amazonaws.com" : ""}"
    es = "${var.fips ? "https://es-fips.us-east-1.amazonaws.com" : ""}"
    fms = "${var.fips ? "https://fms-fips.us-east-1.amazonaws.com" : ""}"
    glacier = "${var.fips ? "https://glacier-fips.us-east-1.amazonaws.com" : ""}"
    guardduty = "${var.fips ? "https://guardduty-fips.us-east-1.amazonaws.com" : ""}"
    inspector = "${var.fips ? "https://inspector-fips.us-east-1.amazonaws.com" : ""}"
    kinesis = "${var.fips ? "https://kinesis-fips.us-east-1.amazonaws.com" : ""}"
    kms = "${var.fips ? "https://kms-fips.us-east-1.amazonaws.com" : ""}"
    lambda = "${var.fips ? "https://lambda-fips.us-east-1.amazonaws.com" : ""}"
    mq = "${var.fips ? "https://mq-fips.us-east-1.amazonaws.com" : ""}"
    pinpoint = "${var.fips ? "https://pinpoint-fips.us-east-1.amazonaws.com" : ""}"
    quicksight = "${var.fips ? "https://fips-us-east-1.quicksight.aws.amazon.com" : ""}"
    rds = "${var.fips ? "https://rds-fips.us-east-1.amazonaws.com" : ""}"
    redshift = "${var.fips ? "https://redshift-fips.us-east-1.amazonaws.com" : ""}"
    resourcegroups = "${var.fips ? "https://resource-groups-fips.us-east-1.amazonaws.com" : ""}"
    route53 = "${var.fips ? "https://route53-fips.amazonaws.com" : ""}"
    s3 = "${var.fips ? "https://s3-fips.us-east-1.amazonaws.com" : ""}"
    sagemaker = "${var.fips ? "https://api-fips.sagemaker.us-east-1.amazonaws.com" : ""}"
    secretsmanager = "${var.fips ? "https://secretsmanager-fips.us-east-1.amazonaws.com" : ""}"
    servicecatalog = "${var.fips ? "https://servicecatalog-fips.us-east-1.amazonaws.com" : ""}"
    ses = "${var.fips ? "https://email-fips.us-east-1.amazonaws.com" : ""}"
    shield = "${var.fips ? "https://shield-fips.us-east-1.amazonaws.com" : ""}"
    sns = "${var.fips ? "https://sns-fips.us-east-1.amazonaws.com" : ""}"
    sqs = "${var.fips ? "https://sqs-fips.us-east-1.amazonaws.com" : ""}"
    ssm = "${var.fips ? "https://ssm-fips.us-east-1.amazonaws.com" : ""}"
    sts = "${var.fips ? "https://sts-fips.us-east-1.amazonaws.com" : ""}"
    swf = "${var.fips ? "https://swf-fips.us-east-1.amazonaws.com" : ""}"
    waf = "${var.fips ? "https://waf-fips.amazonaws.com" : ""}"
    wafregional = "${var.fips ? "https://waf-regional-fips.us-east-1.amazonaws.com" : ""}"
    wafv2 = "${var.fips ? "https://wafv2-fips.us-east-1.amazonaws.com" : ""}"
  }
}

provider "aws" {
  endpoints  {
    acm = "${local.fips_endpoints["acm"]}"
    acmpca = "${local.fips_endpoints["acmpca"]}"
    apigateway = "${local.fips_endpoints["apigateway"]}"
    appstream = "${local.fips_endpoints["appstream"]}"
    cloudformation = "${local.fips_endpoints["cloudformation"]}"
    cloudfront = "${local.fips_endpoints["cloudfront"]}"
    cloudtrail = "${local.fips_endpoints["cloudtrail"]}"
    codebuild = "${local.fips_endpoints["codebuild"]}"
    codecommit = "${local.fips_endpoints["codecommit"]}"
    codedeploy = "${local.fips_endpoints["codedeploy"]}"
    cognitoidentity = "${local.fips_endpoints["cognitoidentity"]}"
    cognitoidp = "${local.fips_endpoints["cognitoidp"]}"
    configservice = "${local.fips_endpoints["configservice"]}"
    datasync = "${local.fips_endpoints["datasync"]}"
    directconnect = "${local.fips_endpoints["directconnect"]}"
    dms = "${local.fips_endpoints["dms"]}"
    ds = "${local.fips_endpoints["ds"]}"
    dynamodb = "${local.fips_endpoints["dynamodb"]}"
    ec2 = "${local.fips_endpoints["ec2"]}"
    ecr = "${local.fips_endpoints["ecr"]}"
    elasticache = "${local.fips_endpoints["elasticache"]}"
    elasticbeanstalk = "${local.fips_endpoints["elasticbeanstalk"]}"
    elb = "${local.fips_endpoints["elb"]}"
    emr = "${local.fips_endpoints["emr"]}"
    es = "${local.fips_endpoints["es"]}"
    fms = "${local.fips_endpoints["fms"]}"
    glacier = "${local.fips_endpoints["glacier"]}"
    guardduty = "${local.fips_endpoints["guardduty"]}"
    inspector = "${local.fips_endpoints["inspector"]}"
    kinesis = "${local.fips_endpoints["kinesis"]}"
    kms = "${local.fips_endpoints["kms"]}"
    lambda = "${local.fips_endpoints["lambda"]}"
    mq = "${local.fips_endpoints["mq"]}"
    pinpoint = "${local.fips_endpoints["pinpoint"]}"
    quicksight = "${local.fips_endpoints["quicksight"]}"
    rds = "${local.fips_endpoints["rds"]}"
    redshift = "${local.fips_endpoints["redshift"]}"
    resourcegroups = "${local.fips_endpoints["resourcegroups"]}"
    route53 = "${local.fips_endpoints["route53"]}"
    s3 = "${local.fips_endpoints["s3"]}"
    sagemaker = "${local.fips_endpoints["sagemaker"]}"
    secretsmanager = "${local.fips_endpoints["secretsmanager"]}"
    servicecatalog = "${local.fips_endpoints["servicecatalog"]}"
    ses = "${local.fips_endpoints["ses"]}"
    shield = "${local.fips_endpoints["shield"]}"
    sns = "${local.fips_endpoints["sns"]}"
    sqs = "${local.fips_endpoints["sqs"]}"
    ssm = "${local.fips_endpoints["ssm"]}"
    sts = "${local.fips_endpoints["sts"]}"
    swf = "${local.fips_endpoints["swf"]}"
    waf = "${local.fips_endpoints["waf"]}"
    wafregional = "${local.fips_endpoints["wafregional"]}"
    wafv2 = "${local.fips_endpoints["wafv2"]}"
  }
}

# https://www.andreagrandi.it/2017/08/25/getting-latest-ubuntu-ami-with-terraform/
data "aws_ami" "ubuntu" {
    most_recent = true

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["099720109477"] # Canonical
}

data "aws_vpc" "vpc" {
    filter {
        name   = "tag:Name"
        values = ["${var.vpc_name}"]
    }
}

data "aws_subnet" "public" {
  filter {
      name   = "tag:Name"
      values = ["${var.subnet_name}"]
  }
  vpc_id = "${data.aws_vpc.vpc.id}"
}

data "aws_security_group" "ssh_in" {
  filter {
      name   = "group-name"
      values = ["${var.ssh_in_secgroup}"]
  }
  vpc_id = "${data.aws_vpc.vpc.id}"
}

data "aws_security_group" "egress" {
  filter {
      name   = "group-name"
      values = ["${var.egress_secgroup}"]
  }
  vpc_id = "${data.aws_vpc.vpc.id}"
}



resource "aws_iam_role" "role" {
  name = "${var.vm_name}-${var.vpc_name}-public_role"
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

  tags = {
    tag-key = "${var.vpc_name}-public"
  }
}

resource "aws_iam_instance_profile" "profile" {
  name = "${var.vm_name}-${var.vpc_name}-public_instance-profile"
  role = "${aws_iam_role.role.name}"
}


resource "aws_iam_policy_attachment" "profile-attach" {
  count      = "${length(var.policies)}"
  name       = "${var.vm_name}-${var.vpc_name}-public-${count.index}"
  roles      = ["${aws_iam_role.role.name}"]
  policy_arn = "${element(var.policies,count.index)}"
}


resource "aws_instance" "cluster" {
  ami                    = "${var.ami == "" ? data.aws_ami.ubuntu.id : var.ami}"
  instance_type          = "${var.instance_type}"
  monitoring             = false
  vpc_security_group_ids = ["${data.aws_security_group.ssh_in.id}", "${data.aws_security_group.egress.id}"]
  subnet_id              = "${data.aws_subnet.public.id}"
  iam_instance_profile   = "${aws_iam_instance_profile.profile.name}"
  root_block_device {
    volume_size = "${var.volume_size}"
    encrypted = true
  }

  user_data = <<EOF
#!/bin/bash 

(
  if [[ ! -f /home/ubuntu/.ssh/authorized_keys ]]; then
    mkdir -p /home/ubuntu/.ssh/authorized_keys
    chown ubuntu: /home/ubuntu/.ssh/authorized_keys
    chmod 0600 /home/ubuntu/.ssh/authorized_keys
  fi
  cat - >> /home/ubuntu/.ssh/authorized_keys <<EOM
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDiVYoa9i91YL17xWF5kXpYh+PPTriZMAwiJWKkEtMJvyFWGv620FmGM+PczcQN47xJJQrvXOGtt/n+tW1DP87w2rTPuvsROc4pgB7ztj1EkFC9VkeaJbW/FmWxrw2z9CTHGBoxpBgfDDLsFzi91U2dfWxRCBt639sLBfJxHFo717Xg7L7PdFmFiowgGnqfwUOJf3Rk8OixnhEA5nhdihg5gJwCVOKty8Qx73fuSOAJwKntcsqtFCaIvoj2nOjqUOrs++HG6+Fe8tGLdS67/tvvgW445Ik5JZGMpa9y0hJxmZj1ypsZv/6cZi2ohLEBCngJO6d/zfDzP48Beddv6HtL rarya_id_rsa
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDBFbx4eZLZEOTUc4d9kP8B2fg3HPA8phqJ7FKpykg87w300H8uTsupBPggxoPMPnpCKpG4aYqgKC5aHzv2TwiHyMnDN7CEtBBBDglWJpBFCheU73dDl66z/vny5tRHWs9utQNzEBPLxSqsGgZmmN8TtIxrMKZ9eX4/1d7o+8msikCYrKr170x0zXtSx5UcWj4yK1al5ZcZieZ4KVWk9/nPkD/k7Sa6JM1QxAVZObK/Y9oA6fjEFuRGdyUMxYx3hyR8ErNCM7kMf8Yn78ycNoKB5CDlLsVpPLcQlqALnBAg1XAowLduCCuOo8HlenM7TQqohB0DO9MCDyZPoiy0kieMBLBcaC7xikBXPDoV9lxgvJf1zbEdQVfWllsb1dNsuYNyMfwYRK+PttC/W37oJT64HJVWJ1O3cl63W69V1gDGUnjfayLjvbyo9llkqJetprfLhu2PfSDJ5jBlnKYnEj2+fZQb8pUrgyVOrhZJ3aKJAC3c665avfEFRDO3EV/cStzoAnHVYVpbR/EXyufYTh7Uvkej8l7g/CeQzxTq+0UovNjRA8UEXGaMWaLq1zZycc6Dx/m7HcZuNFdamM3eGWV+ZFPVBZhXHwZ1Ysq2mpBEYoMcKdoHe3EvFu3eKyrIzaqCLT5LQPfaPJaOistXBJNxDqL6vUhAtETmM5UjKGKZaQ== emalinowski@uchicago.edu
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDKJR5N5VIU9qdSfCtlskzuQ7A5kNn8YPeXsoKq0HhYZSd4Aq+7gZ0tY0dFUKtXLpJsQVDTflINc7sLDDXNp3icuSMmxOeNgvBfi8WnzBxcATh3uqidPqE0hcnhVQbpsza1zk8jkOB2o8FfBdDTOSbgPESv/1dnGApfkZj96axERUCMzyyUSEmif2moWJaVv2Iv7O+xjQqIZcMXiAo5BCnTCFFKGVOphy65cOsbcE02tEloiZ3lMAPMamZGV7SMQiD3BusncnVctn/E1vDqeozItgDrTdajKqtW0Mt6JFONVFobzxS8AsqFwaHiikOZhKq2LoqgvbXZvNWH2zRELezP jawadq@Jawads-MacBook-Air.local
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC+iK0ZvY25lgwh4nNUTkD0bq2NES3cPEK+f52HEC2GSVI845ZOqX32kfNpDFT9zvspadOA6KwAgKsRphP/iV8k8WLjAYSYQ3sAE/enuW1+Cr0hhmtahA+uxOavUwsvJ93vIOlIlkD26gIUZTZeYUhi6Aa2FjWFTJ0CtxtUYEdBh+sqW3VoyVvOOA+2DnNYt7/pTrh0DwNxHX7+9TfkmRaVLD4xcdwNLx5N3Yyjgci+oGmw8HATYfSBTaGEXSKJflrN6TDqN87D2pJpMkEvYeZIktoU0kX4HwodrNfwhlruJ2PsePzZ28xlaaZz2fI/LGiqnwf1fRY10R5C/9RpcAcpcYaz305uBCUCI7GGbL9u7WC0W0NZsyaaybaKXyt97p/05os2oe/N5un0whv+NL8z5SLZnaelvttrmVKApvsCD/IqZv5b2PlDilY3L638eKmVOcHaLX/N67MeL9FKnipv2QPzaUKhMoEAtSPqdOWnlndt9dmMBlqT0BKmB85mm0k= ajoa@uchicago.edu
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCdIXKLMs14c8U9exX/sOoIcvOCZ4v2pKsjdM1VBA56GyI98E1R+hxTBecHeWri9MeQcZkrlmjqT3ZzCb87+n0W2LEWquLNfeheAEq61ogi0taxWEpnb4rIAr1U9aS3d0mk5NIIivrwaUHTIvUhH8mn4Pek0GgybZAsjN/MpZ9PZwUtXNmjZoY5gWR0QO4ZWu7ARknFoNcTXwpWyl/Khhal0KKhdB38y3MpJc03IIqhem15e78jRlko04CAZX3zlFAQwbxnrpgrJUMYeY8fZqpV6FiWC40yu+n9KwAZkmtrc45mkxahj8c3QtJ/Z3t33yXEN9PEHV6z104STYi2cPVD rpollard@news-MacBook-Pro.local
EOM
)
(
  export DEBIAN_FRONTEND=noninteractive
    
  if which hostnamectl > /dev/null; then
    hostnamectl set-hostname 'lab${count.index}'
  fi
  mkdir -p -m 0755 /var/lib/gen3
  cd /var/lib/gen3
  if ! which git > /dev/null; then
    apt update
    apt install git -y
  fi
  git clone https://github.com/uc-cdis/cloud-automation.git 
  cd ./cloud-automation
  cat ./files/authorized_keys/ops_team | tee -a /home/ubuntu/.ssh/authorized_keys

  if [[ ! -d ./Chef ]]; then
    # until the code gets merged
    git checkout chore/labvm
  fi

  cd ./Chef
  bash ./installClient.sh
  # hopefully chef-client is ready to run now
  cd ./repo
  /bin/rm -rf nodes
  # add -l debug for more verbose logging
  chef-client --chef-license accept --local-mode --node-name littlenode --override-runlist 'role[devbox]'
) 2>&1 | tee /var/log/gen3boot.log
  EOF
  
  lifecycle {
    # Due to several known issues in Terraform AWS provider related to arguments of aws_instance:
    # (eg, https://github.com/terraform-providers/terraform-provider-aws/issues/2036)
    # we have to ignore changes in the following arguments
    ignore_changes = ["private_ip", "root_block_device", "ebs_block_device", "user_data"]
  }
  tags = {
    Name        = "${var.vm_name}-${var.vpc_name}-public"
    Terraform   = "true"
    Environment = "${var.vpc_name}"
  }
}

resource "aws_eip" "ips" {
  instance = "${aws_instance.cluster.id}"
  vpc      = true
}

