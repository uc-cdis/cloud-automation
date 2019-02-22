#!/bin/bash



server_int=$(route | grep '^default' | grep -o '[^ ]*$')
instance_ip=$(ip -f inet -o addr show $server_int|cut -d\  -f 7 | cut -d/ -f 1)
route_table_id=$(sed -n -e '/VAR2/ s/.*\= *//p' /home/ubuntu/squid_auto_user_variable)

squid_auto_interface_id=$(aws ec2 describe-instances  --filters "Name=network-interface.addresses.private-ip-address,Values=$instance_ip" --query 'Reservations[*].Instances[*].{ID:NetworkInterfaces[0].NetworkInterfaceId}' --region us-east-1 --output text)

echo " The squid auto inteface id is ..."
echo $squid_auto_interface_id

echo "Creating the default route....."
aws ec2 create-route  --route-table-id $route_table_id --destination-cidr-block 1.1.1.1/32 --network-interface-id $squid_auto_interface_id
echo "Updating the default route ...."
aws ec2 replace-route  --route-table-id $route_table_id --destination-cidr-block 1.1.1.1/32 --network-interface-id $squid_auto_interface_id
