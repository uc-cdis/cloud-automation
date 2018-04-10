#!/bin/bash
if [ $# -ne 1 ]; then
    echo "USAGE: $0 name_of_child_vpc"
    exit 1
fi
vpcpeering_pending_acceptence=$(aws ec2 describe-vpc-peering-connections --filters Name=status-code,Values=pending-acceptance --output text)
if [ -n "$vpcpeering_pending_acceptence" ]; then
child_vpc_name=$1
vpcpeerconnid=$(aws ec2 describe-vpc-peering-connections --filters Name=status-code,Values=pending-acceptance --query 'VpcPeeringConnections[*].VpcPeeringConnectionId' --output text)
vpccidrblock=$(aws ec2 describe-vpc-peering-connections --filters Name=status-code,Values=pending-acceptance --query 'VpcPeeringConnections[*].RequesterVpcInfo.CidrBlock' --output text)

aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $vpcpeerconnid
aws ec2 create-tags --resources $vpcpeerconnid --tags Key=Name,Value="VPC peering between $child_vpc_name and csoc_main_vpc"
echo "The vpc peering connection request for id $vpcpeerconnid was accepted"


aws ec2 create-route --route-table-id rtb-23b6685f --destination-cidr-block $vpccidrblock --vpc-peering-connection-id $vpcpeerconnid
echo "The route for the child vpc $child_vpc_name cidr $vpccidrblock was added"
exit 1
else echo "CSOC AWS account haven't received the VPC peering request yet"
fi
