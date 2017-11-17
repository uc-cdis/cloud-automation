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
2. create deployment with secrets mounted
3. create service for the pods

### Create secrets
Secret is the way in which Kubernetes uses to manage the confidential information such as `ssh_key`, private setting containing `username`, `password` of a `database`, or a `service`. Run the following command with `SECRET_NAME` is the name of secret entry managed by kubernetes, `OUTPUT_FILE` is the file name that you expect to see in the container, and `PATH_TO_INPUT_FILE` is path to the input of that secret.
```
kubectl create secret generic SECRET_NAME --from-file=OUTPUT_FILE=PATH_TO_INPUT_FILE
```

### Update secrets or configMaps
To update a secret or config map, you can delete and recreate it.
```
kubectl delete configmap userapi
kubectl create configmap userapi --from-file=apis_configs/user.yaml
```

There is currently no way for deployments to recognize that a secret or configmap is updated, but you can enforce a rolling update by doing a patch:
```
kubectl patch deployment $deployment_name -p   "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"

```
### Create deployment/service
A deployment or service is usually defined in a [configuration file](https://github.com/uc-cdis/cloud-automation/blob/master/kube/services/gdcapi/gdcapi-deploy.yaml).

Run the following command to create the deployment defined in that file in Kubernetes.
```
kubectl create -f PATH_TO_DEFINITION_FILE
```

Having the container running, we can access to the container by the following command:
```
kubectl exec -ti POD_NAME -c CONTAINER_NAME /bin/bash
```

We can also retrieve all the log traced from the container to the pod by:
```
kubectl logs POD_NAME
```
If you want to keep watching logs for debugging, do:
```
kubectl logs --tail=20 POD_NAME -f
```

Use `kubectl apply -f PATH_TO_CONFIG_FILE` to update a running deployment. Set `save-config` flag to `true` if the configuration of current object is intended to save in its annotation.

### Mount secrets to container
Secrets are passed to container in the initial phase by mounting as a volume. We can include the mounted secrets into the definition file as [this example](https://github.com/uc-cdis/cloud-automation/blob/master/kube/services/userapi/userapi-deploy.yaml#L25-L28)

In this example, we want the `local_settings.py` to be located in the same directory with running script. We need to specify two keys (`mountPath` and `subPath`) in each entry of `volumeMounts`. In particular, `mountPath` is the fullpath contains also the name of file, while `subPath` is the file name.

## Expose a service internally with DNS
Domain name should be used to point to a service. Domain name is only recognized at the Pod level, not the Node level.  It means that we need to access to either pod or container to see other container/pod by its domain name.

## Expose a service externally
Currently services are exposed via NodePort since that requires minimal overhead and we are not using a huge cluster that needs load balance. We setup the NodePort and open this port in the security group inbound rule, then we have a reverseproxy outside of the kube cluster which proxy all traffics to services.

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
kubectl proxy --port 9090
```
Then you can do ssh port forward from your laptop:
```
ssh -L9090:localhost:9090 -N kube_provisioner_vm
```

### Setting up users and roles

K8s 1.6.+ includes RBAC support for both user and service accounts, but the RBAC plugin is 
not enabled by default in the latest stable kube-aws release - the next stable release of kube-aws [(v0.9.9)](https://github.com/kubernetes-incubator/kube-aws/releases) will
[enable RBAC enforcement by default](https://github.com/kubernetes-incubator/kube-aws/issues/655).

* [service accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) are intended for use by pods running on the cluster.
   If not otherwise specified a pod is automatically associated with the 'default' service account.  (https://kubernetes.io/docs/admin/authorization/rbac/#upgrading-from-15).
    * [service accounts administration guide](https://kubernetes.io/docs/admin/service-accounts-admin/)
    * [linking pods with service accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
    * [k8s built in secrets management](https://kubernetes.io/docs/concepts/configuration/secret/#built-in-secrets) automatically handles injecting service account credentials into pods
    * [upgrading non-RBAC clusters](https://kubernetes.io/docs/admin/authorization/rbac/#upgrading-from-15) - the current kube-aws 'default' service account currently grants admin privileges on the cluster to all services - v0.9.9 will enable RBAC
    by default with reasonble roles for the different core services.

* user accounts 
    * k8s supports multiple [approaches to authentication](https://kubernetes.io/docs/admin/authentication/)
    * [k8s RBAC](https://kubernetes.io/docs/admin/authorization/rbac/) is one way to restrict how an authenticated user can access k8s
    * k8s also supports [ABAC](https://kubernetes.io/docs/admin/authorization/abac/) (attribute based acess control)
    * [this page](https://docs.bitnami.com/kubernetes/how-to/configure-rbac-in-your-kubernetes-cluster/#use-case-1-create-user-with-limited-namespace-access) walks through creating a user account authenticated via a TLS certificate and associated with an RBAC role
  

### Services
#### [userapi](https://github.com/uc-cdis/user-api)
The authentication and authorization provider.
#### [gdcapi](https://github.com/uc-cdis/gdcapi/)
API for submitting and query graph data model that stores the metadata for this cluster.
#### [indexd](https://github.com/LabAdvComp/indexd)
ID service that tracks all data blobs in different storage locations
#### [data-portal](https://github.com/uc-cdis/data-portal)
Portal to browse and submit metadata.
#### [kafka](https://github.com/uc-cdis/kubernetes-kafka)
Kafka cluster that support different data streams for the system.
#### [elk](https://github.com/uc-cdis/kubernetes-elk)
Elasticsearch-Logstash-Kibana pod for log aggregation using filebeat.

### bash functions
There are some helper functions in [kubes.sh](https://github.com/uc-cdis/cloud-automation/blob/master/kube/kubes.sh) for k8s related operations.

#### patch_kube
`patch_kube $DEPLOYMENT_NAME` to let k8s recycle pods when there is no change.

#### get_pod
`get_pod $DEPLOYMENT_SUBSTRING` get one of the pods' name for a deployment, this is handy when you want to just run a command on one pod, eg:
`kubectl exec $(get_pod gdcapi) -c gdcapi ls`.

#### update_config
`update_config $CONFIG_NAME $CONFIG_FILE` this will delete old configmap and create new configmap with updated content
