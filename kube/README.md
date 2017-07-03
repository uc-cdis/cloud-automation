# Configuration for setting up a kubernete cluster inside an existing VPC private subnet

## Manual Prerequisites

- need to have at least 1 eips
- need to get the credential from quay.io for [cdis-devservices robot](https://quay.io/organization/cdis?tab=robots)

## Steps to start all services
1. Copy the ${cluster}_output folder to the kube.internal.io (Kubernete provisioner)
2. Run kube-up.sh
3. [Upgrade kubenete](https://github.com/uc-cdis/cloud-automation/blob/master/kube/README.md#upgrade-kubernete) to 1.7.0 if the version is still the broken 1.6.3
4. Get quay creds in prerequisites 2 to ${cluster}/cdis-devservices-secret.yml
5. Run kube-services.sh
6. Register your kubernete worker nodes as `kubenode.internal.io` in your route53
7. Adjust the security group for kubernete workers to allow TCP port `30000-30100` inbound traffic from `172.16.0.0/16`
7. Copy the `revproxy-setup.sh` and `proxy.conf` in the ${cluster}_output directory to `revproxy.internal.io` and run the `revproxy-setup.sh` script.
8. Setup DNS for your revproxy node to your hostname, or edit /etc/hosts file locally to point to the elastic ip of your revproxy node. Then you should be able to browse to the portal through the hostname you setup.

## Steps to start a new service
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

### Update secrets or configMaps
To update a secret or config map, you can delete and recreate it.
```
kubectl --kubeconfig=kubeconfig delete configmap userapi
kubectl --kubeconfig=kubeconfig create configmap userapi --from-file=apis_configs/user.yaml
```

There is currently no way for deployments to recognize that a secret or configmap is updated, but you can enforce a rolling update by doing a patch:
```
kubectl --kubeconfig=kubeconfig patch deployment $deployment_name -p   "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"

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
```

### Upgrade kubernete
To upgrade kubectl on current VM, you can download the latest one and replace the binary.
```
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

```
To upgrade kubernete, you can follow the instruction [here](https://coreos.com/kubernetes/docs/latest/kubernetes-upgrade.html)
But basically, you need to ssh onto nodes via `ssh core@$ip_address`, and run:
```
sudo su
old_version='1.6.4'
new_version='1.7.0'
sed -i s/$old_version/$new_version/g /run/systemd/system/kubelet.service
systemctl daemon-reload
systemctl restart kubelet.service

sed -i s/$old_version/$new_version/g /etc/kubernetes/manifests/*
```
It will take a minute to install the new containers and reload

### Accessing kubernete dashboard
To access the kubernete api/ui, you can start a proxy on the kube provisioner VM:
```
kubectl --kubeconfig=kubeconfig proxy --port 9090
```
Then you can do ssh port forward from your laptop:
```
ssh -L9090:localhost:9090 -N kube_provisioner_vm
```

### Services
#### [userapi](https://github.com/uc-cdis/user-api)
The authentication and authorization provider.
#### [gdcapi](https://github.com/uc-cdis/gdcapi/)
API for submitting and query graph data model that stores the metadata for this cluster.
#### [indexd](https://github.com/LabAdvComp/indexd)
ID service that tracks all data blobs in different storage locations
### [data-portal](https://github.com/uc-cdis/data-portal)
Portal to browse and submit metadata.
### [kafka](https://github.com/uc-cdis/kubernetes-kafka)
Kafka cluster that support different data streams for the system.
### [elk](https://github.com/uc-cdis/kubernetes-elk)
Elasticsearch-Logstash-Kibana pod for log aggregation using filebeat.
