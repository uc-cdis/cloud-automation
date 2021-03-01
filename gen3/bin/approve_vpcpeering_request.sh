#!/bin/bash
if [ $# -lt 1 ]; then
    echo "USAGE: $0 name_of_child_vpc"
    exit 1
fi
vpcpeering_pending_acceptence=$(aws ec2 describe-vpc-peering-connections --filters Name=status-code,Values=pending-acceptance --output text)
if [ -n "$vpcpeering_pending_acceptence" ]; then

    child_vpc_name=$1
    vpcpeerconnid=$(aws ec2 describe-vpc-peering-connections --filters Name=status-code,Values=pending-acceptance --query 'VpcPeeringConnections[*].VpcPeeringConnectionId' --output text)
    vpccidrblock=$(aws ec2 describe-vpc-peering-connections --filters Name=status-code,Values=pending-acceptance --query 'VpcPeeringConnections[*].RequesterVpcInfo.CidrBlock' --output text)
    acceptervpcid=$(aws ec2 describe-vpc-peering-connections --filters Name=status-code,Values=pending-acceptance --query 'VpcPeeringConnections[*].AccepterVpcInfo.VpcId' --output text)
    ROUTE_TABLES=(rtb-23b6685f rtb-7ee06301)
    if [ $# -eq 2 ]; then
        while test $# -gt 0; do
            case "$2" in
            --get-route-table)
                shift
                ROUTE_TABLES=($(aws ec2 describe-route-tables --filters Name=vpc-id,Values=${acceptervpcid} --query 'RouteTables[*].RouteTableId' --output text))
                shift
                ;;
            *)
                echo "$2 is not a recognized flag!"
                exit 1
                ;;
            esac
        done
    fi

    echo "Route Table: ${ROUTE_TABLES[*]}"

    aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $vpcpeerconnid
    aws ec2 create-tags --resources $vpcpeerconnid --tags Key=Name,Value="VPC peering between $child_vpc_name and csoc_main_vpc"
    echo "The vpc peering connection request for id $vpcpeerconnid was accepted"

    for table_id in "${ROUTE_TABLES[@]}"; do
        aws ec2 create-route --route-table-id $table_id --destination-cidr-block $vpccidrblock --vpc-peering-connection-id $vpcpeerconnid
    done

    echo "The route for the child vpc $child_vpc_name cidr $vpccidrblock was added"
    exit 1
else
    echo "CSOC AWS account haven't received the VPC peering request yet"
fi

