# TL;DR

Applying iam intergraion with service accounts in kubernetes 

## Overview

IAM integration with service accounts in kubernetes requires a few things to be in place.

Firstly, since gen3 is mostly hosted on AWS, we need to create and OIDC [OpenID Connect (protocol)] in AWS. This will allow service accounts in kubernetes pull IAM roles defined in the account your k8s (EKS in our case) is running, and let pods attached to service accounts talk to endpoints or services the roles in question are allowing.

The OIDC creation happens automatically through terraform, nonetheless no roles nor service accounts are created or anything that would get this started. You must define roles and permissions for later to be use by pods attaches to service accounts also defined by you.

We have created a script that should help you out in the roles and policies creation in AWS for later use with service accounts. You could check out the options by running `gen3 iam-serviceaccount -h`. 

Basically, what is does to get this started is creating a role and a service account. When the service account is created, it will automatically attach the role to it. For more information about what happening under the hood, please access https://eksworkshop.com/irsa/preparation/ and https://aws.amazon.com/blogs/opensource/introducing-fine-grained-iam-roles-service-accounts/

It worth noting that this kind of configuraion will only work with EKS 1.13+. If you are running a lower version, you must update first in order to avoid errors and incompatibilities, then enable the feature. For more information go to https://github.com/uc-cdis/cloud-automation/tree/master/tf_files/aws/modules/eks#5-considerations


What `gen3 iam-serviceaccount` does is basically the following:


## Role, policy, and service account creation:

### STEP 1: create IAM role and attach the target policy:


```bash
$ ISSUER_URL=$(aws eks describe-cluster \
                       --name ${vpc_name} \
                       --query cluster.identity.oidc.issuer \
                       --output text)
$ ISSUER_HOSTPATH=$(echo $ISSUER_URL | cut -f 3- -d'/')
$ ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
$ PROVIDER_ARN="arn:aws:iam::$ACCOUNT_ID:oidc-provider/$ISSUER_HOSTPATH"
$ cat > irp-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$PROVIDER_ARN"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${ISSUER_HOSTPATH}:sub": "system:serviceaccount:default:my-serviceaccount"
          "${ISSUER_HOSTPATH}:aud": "sts.amazonaws.com",
        }
      }
    }
  ]
}
EOF
$ ROLE_NAME=s3-reader
$ aws iam create-role \
          --role-name $ROLE_NAME 
          --assume-role-policy-document file://irp-trust-policy.json
$ aws iam attach-role-policy \
          --role-name $ROLE_NAME \
          --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
$ S3_ROLE_ARN=$(aws iam get-role \
                        --role-name $ROLE_NAME \
                        --query Role.Arn --output text)
```


### STEP 2: create Kubernetes service account and annotate it with the IAM role:

```bash
$ kubectl create sa my-serviceaccount
$ kubectl annotate sa my-serviceaccount eks.amazonaws.com/role-arn=$S3_ROLE_ARN
```



## With gen3 iam-serviceaccount

You can achieve the same results as the two steps above by running something like:

```bash
gen3 iam-serviceaccount -c <service-account-name> -p <policy-name>

```

Ex:

```bash 
gen3 iam-serviceaccount -c my-serviceaccount -p AmazonS3ReadOnlyAccess
```


The above command will create the role with the assume role policy already and also attach the AmazonS3ReadOnlyAccess policy to the newly created role.


## Pods configuration

Once you have a role and a service account, you are ready to configure your deployments/pods/job/daemonsets/etc to use the service acocunt. For that you need to add a few new fields in you configuration.

This is an example deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: generic-app
    public: "yes"
  name: generic-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: generic-app
  template:
    metadata:
      labels:
        app: generic-app
        public: "yes"
    spec:
      serviceAccountName: my-serviceaccount
      containers:
      - image: quay.io/cdis/awshelper:master
        name: generic-deployment
        command: ["/bin/bash" ]
        args:
          - "-c"
          - |
            while true; do echo "I am here"; echo $(whoami); sleep 60; done
        imagePullPolicy: Always
```

Note: environmental variables and mounts are not required, and will be automatically populated by K8s according `service-account`.


The pod that gets deployed off the deployment with the above configuration will be able to talk to S3, in this particular case a read only access.

