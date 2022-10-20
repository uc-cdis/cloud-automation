
# Assuming that there is only one VPC with the vpc_name
data "aws_vpc" "the_vpc" {
  id = data.aws_vpcs.vpcs.ids[0]
}

# Let's grab the vpc we already created in the VPC module.
data "aws_vpcs" "vpcs" {
  tags = {
    Name = var.vpc_name
  }
}

data "aws_subnet" "public_kube" {
  vpc_id = data.aws_vpc.the_vpc.id
  tags = {
    Name = "eks_public_2"
  }
}

data "aws_storagegateway_local_disk" "storage-gateway-data" {
  disk_path   = aws_volume_attachment.disk-attach.device_name
  gateway_arn = aws_storagegateway_gateway.storage-gateway.arn
}
