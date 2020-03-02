#!/bin/bash

## Creating the default route for the private subnets route tables

server_int=$(route | grep '^default' | grep -o '[^ ]*$')
instance_ip=$(ip -f inet -o addr show $server_int|cut -d\  -f 7 | cut -d/ -f 1)
route_table_id1=$(sed -n -e '/VAR2/ s/.*\= *//p' /home/ubuntu/squid_auto_user_variable)
route_table_id2=$(sed -n -e '/VAR3/ s/.*\= *//p' /home/ubuntu/squid_auto_user_variable)

availability_zone=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone -s)
region=$(echo ${availability_zone::-1})

squid_auto_interface_id=$(aws ec2 describe-instances  --filters "Name=network-interface.addresses.private-ip-address,Values=$instance_ip" --query 'Reservations[*].Instances[*].{ID:NetworkInterfaces[0].NetworkInterfaceId}' --region ${region} --output text)

echo " The squid auto inteface id is ..."
echo $squid_auto_interface_id

echo "Creating the default route for eks private route table....."
aws ec2 create-route  --route-table-id $route_table_id1 --destination-cidr-block 0.0.0.0/0 --network-interface-id $squid_auto_interface_id --region ${region}
echo "Updating the default route for eks private route table ...."
aws ec2 replace-route  --route-table-id $route_table_id1 --destination-cidr-block 0.0.0.0/0 --network-interface-id $squid_auto_interface_id --region ${region}


echo "Creating the default route for private kube route table....."
aws ec2 create-route  --route-table-id $route_table_id2 --destination-cidr-block 0.0.0.0/0 --network-interface-id $squid_auto_interface_id --region ${region}
echo "Updating the default route for private kube route table ...."
aws ec2 replace-route  --route-table-id $route_table_id2 --destination-cidr-block 0.0.0.0/0 --network-interface-id $squid_auto_interface_id --region ${region}






## disable the source destination check on the instance
echo "Disabling the source destination check on the instance....."
aws ec2 modify-network-interface-attribute --network-interface-id $squid_auto_interface_id  --no-source-dest-check --region ${region}



