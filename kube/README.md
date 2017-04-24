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
