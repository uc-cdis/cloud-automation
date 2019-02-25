#!/bin/bash



server_int=$(route | grep '^default' | grep -o '[^ ]*$')
proxy_ip=$(ip -f inet -o addr show $server_int|cut -d\  -f 7 | cut -d/ -f 1)
dns_zone_id=$(sed -n -e '/VAR1/ s/.*\= *//p' /home/ubuntu/squid_auto_user_variable)

touch create_proxy_dns_entry.json
cat > create_proxy_dns_entry.json << EOF
{
            "Comment": "CREATE a record ",
            "Changes": [{
            "Action": "CREATE",
                        "ResourceRecordSet": {
                                    "Name": "cloud-proxy.internal.io",
                                    "Type": "A",
                                    "TTL": 300,
                                 "ResourceRecords": [{ "Value": "$proxy_ip"}]
}}]
}
EOF

touch update_proxy_dns_entry.json
cat > update_proxy_dns_entry.json << EOF
{
            "Comment": "UPDATE a record ",
            "Changes": [{
            "Action": "UPSERT",
                        "ResourceRecordSet": {
                                    "Name": "cloud-proxy.internal.io",
                                    "Type": "A",
                                    "TTL": 300,
                                 "ResourceRecords": [{ "Value": "$proxy_ip"}]
}}]
}
EOF


echo "And we are done here....."







aws route53 change-resource-record-sets --hosted-zone-id $dns_zone_id  --change-batch file://create_proxy_dns_entry.json  

aws route53 change-resource-record-sets --hosted-zone-id $dns_zone_id --change-batch file://update_proxy_dns_entry.json 

echo "Removing the proxy dns entry create file"
rm create_proxy_dns_entry.json
echo "Removing the proxy dns update  file"
rm update_proxy_dns_entry.json