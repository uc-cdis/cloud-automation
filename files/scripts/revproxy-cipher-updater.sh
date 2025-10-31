# Get the revproxy ELB name
elbName=$(kubectl get services | grep revproxy-service-elb | rev | cut -d '.' -f 5 | cut -d ' ' -f 1 | rev | cut -d '-' -f 1)
# Create a custom ELB policy for the load balancer
aws elb create-load-balancer-policy --load-balancer-name $elbName  --policy-name customPolicy --policy-type-name SSLNegotiationPolicyType --policy-attributes AttributeName=Protocol-TLSv1.2,AttributeValue=true AttributeName=ECDHE-RSA-AES256-GCM-SHA384,AttributeValue=true AttributeName=ECDHE-RSA-AES128-GCM-SHA256,AttributeValue=true AttributeName=Server-Defined-Cipher-Order,AttributeValue=true
# Update the policy to the new custom one
aws elb set-load-balancer-policies-of-listener --load-balancer-name $elbName --load-balancer-port 443 --policy-names customPolicy
