count_stat1=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names commons_squid_auto_autoscaling_grp --region us-east-1  --query AutoScalingGroups[].Instances[].HealthStatus --output text | grep -w Healthy | awk '{print NF}')

count_stat2=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names commons_squid_auto_autoscaling_grp --region us-east-1  --query AutoScalingGroups[].Instances[].HealthStatus --output text | grep -w Unhealthy | awk '{print NF}')


echo "The count stat is $count_stat1"
echo "The count stat is $count_stat2"


if [[ "$count_stat1" -lt '2'  ||   "$count_stat2" -ge '1' ]] ; then
echo "Running the private subnets route table script"
bash /home/ubuntu/default_ip_route_and_instance_check_config.sh
echo "Running the route53 DNS update script"
bash /home/ubuntu/proxy_route53_config.sh
fi