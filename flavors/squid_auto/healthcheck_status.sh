#!/bin/bash

# We run this script in a loop with a sleep interval of  5 seconds so that the squid VMs can do a health check 
# on the autoscaling group every 5 secs. Please note the VM in autoscaling group only goes Unhealthy/ or not available
# only for a sort duration like 20-25 secs

availability_zone=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone -s)                                                                                                                                                                                                                                                                                               
region=$(echo ${availability_zone::-1}) 

for i in {1..12}
do
timestamp=$(date)

COMMONS_SQUID_AUTO_ROLE=$(sed -n -e '/VAR4/ s/.*\= *//p' /home/ubuntu/squid_auto_user_variable)

count_stat1=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${COMMONS_SQUID_AUTO_ROLE} --region ${region}  --query AutoScalingGroups[].Instances[].HealthStatus --output text | grep -w Healthy | awk '{print NF}')

count_stat2=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${COMMONS_SQUID_AUTO_ROLE} --region ${region}  --query AutoScalingGroups[].Instances[].HealthStatus --output text | grep -w Unhealthy | awk '{print NF}')





if [[ "$count_stat1" -lt '2'  ||   ! -z "$count_stat2" ]] ; then
  echo "The number of Healthy hosts  at $timestamp  is $count_stat1" >> /var/log/squid_health.log
  echo "The number of Unhealthy hosts  at $timestamp is $count_stat2" >> /var/log/squid_health.log
  echo "Running the private subnets route table script at $timestamp" >> /var/log/squid_health.log
  sudo bash /home/ubuntu/default_ip_route_and_instance_check_config.sh
  echo "Running the route53 DNS update script at $timestamp" >> /var/log/squid_health.log
  sudo bash /home/ubuntu/proxy_route53_config.sh
fi

sleep 5
done
