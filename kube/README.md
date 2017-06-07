# Configuration for setting up a kubernete cluster inside an existing VPC private subnet

## Manual Prerequisites

- need to have less than 5 eips
- need to do route53 manually 
- need to add security group for the bootstrap VM to controller's security group for https access
- setup S3 bucket for stack templates
- setup KMS key
- follow direction in [coreos](https://coreos.com/kubernetes/docs/latest/kubernetes-on-aws-render.html)


## Step to start a service
In order to start a service that uses confidential information in container with Kubernetes, we should go through following steps:
1. create secrets needed
2. create deployment
3. mount secrets into the container
4. create service for the pods

### Create secrets
Secret is the way in which Kubernetes uses to manage the confidential information such as `ssh_key`, private setting containing `username`, `password` of a `database`, or a `service`. Run the following command with `SECRET_NAME` is the name of secret entry managed by kubernetes, `OUTPUT_FILE` is the file name that you expect to see in the container, and `PATH_TO_INPUT_FILE` is path to the input of that secret.
```
kubectl --kubeconfig=kubeconfig create secret generic SECRET_NAME --from-file=OUTPUT_FILE=PATH_TO_INPUT_FILE
```

### Create deployment/service
A deployment or service is usually defined in a configuration. The example below shows how to configure to userapi service.
```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: userapi-deployment
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: userapi
    spec:
      containers:
      - name: userapi
        image: quay.io/cdis/user-api:0.1.0
        ports:
        - containerPort: 80
      imagePullSecrets:
        - name: philloooo-pull-secret
```

Run the following command to create the deployment defined in that file in Kubernetes.
```
kubectl --kubeconfig=kubeconfig create -f PATH_TO_DEFINITION_FILE
```

Having the container running, we can access to the container by the following command:
```
kubectl --kubeconfig=kubeconfig exec -ti POD_NAME -c CONTAINER_NAME /bin/bash
```

We can also retrieve all the log traced from the container to the pod by:
```
kubectl --kubeconfig=kubeconfig logs POD_NAME
```

Use `kubectl --kubeconfig=kubeconfig apply -f PATH_TO_CONFIG_FILE` to update a running deployment. Set `save-config` flag to `true` if the configuration of current object is intended to save in its annotation.

### Mount secrets to container
Secrets are passed to container in the initial phase by mounting as a volume. We can include the mounted secrets into the definition file as the following example:

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: userapi-deployment
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: userapi
    spec:
      volumes:
        - name: config-volume
          secret:
            secretName: "userapi-secret"
      containers:
      - name: userapi
        image: quay.io/cdis/user-api:0.1.0
        ports:
        - containerPort: 80
        volumeMounts:
          - name: "config-volume"
            readOnly: true
            mountPath: "/var/www/user-api/local_settings.py"
            subPath: local_settings.py
      imagePullSecrets:
        - name: philloooo-pull-secret
```

In this example, we want the `local_settings.py` to be located in the same directory with running script. We need to specify two keys (`mountPath` and `subPath`) in each entry of `volumeMounts`. In particular, `mountPath` is the fullpath contains also the name of file, while `subPath` is the file name.

### Release a new version of a service
1. create a release version in github
2. wait for quay to build the new version.
3. deploy with kube:  `kubectl --kubeconfig=kubeconfig set image deployment/portal-deployment portal=quay.io/cdis/data-portal:$version_number`

## Expose a service internally with DNS
Domain name should be used to point to a service. Domain name is only recognized at the Pod level, not the Node level.  It means that we need to access to either pod or container to see other container/pod by its domain name.

## Expose a service externally
Currently services are exposed via NodePort since that requires minimal overhead and we are not using a huge cluster that needs load balance. We setup the NodePort and open this port in the security group inbound rule, then we have a reverseproxy outside of the kube cluster which proxy all traffics to services.

### Scale the cluster
To scale up the kubernete cluster, you can use aws autoscaling group directly
```
aws autoscaling describe-auto-scaling-groups | grep AutoScalingGroupName
            "AutoScalingGroupName": "dev-cluster-Controlplane-OEZYUCELKJ4N-Controllers-1819W9DZ2W08V", 
            "AutoScalingGroupName": "dev-cluster-Controlplane-OEZYUCELKJ4N-Etcd0-WD58TDTH03PT", 
            "AutoScalingGroupName": "dev-cluster-Nodepool2-Z1Y7UPYSD17I-Workers-IAR1O6I28D6V", 
aws autoscaling update-auto-scaling-group --auto-scaling-group-name dev-cluster-Nodepool2-Z1Y7UPYSD17I-Workers-IAR1O6I28D6V --desired-capacity 4 --min-size 4 --max-size 4`
