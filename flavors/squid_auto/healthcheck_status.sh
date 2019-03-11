count_stat=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names commons_squid_auto_autoscaling_grp --region us-east-1  --query AutoScalingGroups[].Instances[].HealthStatus --output text | grep Unhealthy | awk '{print NF}')

echo "The count stat is $count_stat"

if [ ! -z "$count_stat" ] ; then
#if [ "$count_stat" -ge 1 ] ; then
echo "Running the private subnets route table script"
bash /home/ubuntu/default_ip_route_and_instance_check_config.sh
echo "Running the route53 DNS update script"
bash /home/ubuntu/proxy_route53_config.sh
fi