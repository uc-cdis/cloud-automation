# Configuration for setting up a kubernete cluster inside an existing VPC private subnet

### Manual Prerequisites

- need to have less than 5 eips
- need to do route53 manually 
- need to add security group for the bootstrap VM to controller's security group for https access
- setup S3 bucket for stack templates
- setup KMS key
- follow direction in [coreos](https://coreos.com/kubernetes/docs/latest/kubernetes-on-aws-render.html)


### Step to start a service
1. configure secrets needed
2. configure deployment
3. create pods by deployment file
4. create service for the pods

### Expose a service externally
Currently services are exposed via NodePort since that requires minimal overhead and we are not using a huge cluster that needs load balance. We setup the NodePort and open this port in the security group inbound rule, then we have a reverseproxy outside of the kube cluster which proxy all traffics to services.

### Release a new version of data-portal
1. create a release version in github
2. wait for quay to build the new version
3. deploy with kube:  `kubectl --kubeconfig=kubeconfig set image deployment/portal-deployment portal=quay.io/cdis/data-portal:$version_number`
