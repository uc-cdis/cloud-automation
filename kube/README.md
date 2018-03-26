# Configuration for setting up a kubernete cluster inside an existing VPC private subnet

## Steps to start all services on a new k8s cluster in AWS
1. Copy the ${cluster}_output folder to the kube.internal.io (Kubernete provisioner)
2. ssh to kube.internal.io (gen3 tfoutput ssh_config or terraform output gives the `~/.ssh/config` entries), and `$ cd ~/${cluster}_output`
3. Run kube-up.sh
4. Run kube-services.sh
5. Optional - register your kubernete worker nodes as `kubenode.internal.io` in your route53


## Steps to start a new service in an existing commons
In order to start a service that uses confidential information in container with Kubernetes, we should go through following steps:
1. rerun terraform, and copy the latest `${cluster}_output` up to kube.internal.io  If you do not run terraform for some reason, then you can often just update `${cluster_output}` on kube.internal.io by hand:
    * Update `~/${cluster}_output/creds.json` with any new creds required
    * Add a *dictionary_url* property to `~/${cluster}/00configmap.yaml` if necessary, and `kubectl apply -f 00configmap.yaml`
2. login to the k8s provisioner, cd into the cluster data folder, and export the vpc_name environment variable (which some helper scripts look for) 
```
$ ssh kube_internal.io; cd ~/${cluster}; export vpc_name="${cluster}"
```
3. update the local copy of cloud-automation (which `kube-services.sh` checked out when the cluster was first setup): 
```
$ cd ~/cloud-automation; git pull
```
4. create secrets needed - including SSL certs (see the helper scripts just below)
3. create deployment with secrets mounted
4. create services for the pods

The following helper script is configured to be safe to run multiple times.
* The kube-services-body.sh script runs each of the following scripts in the proper order:
```
$ bash ~/cloud-automation/tf_files/configs/kube-services-body.sh VPC_NAME
```

* Setup SSL certs and corresponding k8s secrets for all services:
```
$ bash ~/cloud-automation/tf_files/configs/kube-setup-certs.sh VPC_NAME
```
* Deply *fence* - fence will connect to the existing *userapi* database if the database variables are properly configured in `creds.json`.  This script will also update the *gdcapi* configuration, but will not restart *gdcapi*, so you'll need to roll the *gdcapi* pod to kick it to start using fence.  Similarly - this script does not update the reverse proxy to point at *fence* instead of *userapi*.
```
$ bash ~/cloud-automation/tf_files/configs/kube-setup-fence.sh VPC_NAME
```
* Deploy *sheepdog* and *peregrine* - replacing an existing *gdcapi-service* deployment.  These scripts also generate the supporting k8s secrets for the *sheepdog* and *peregrine* services (use *kube-setup-certs.sh* to setup the certs - see above).  Move the commons to *fence* (from *userapi*) before moving to *sheepdog* and *peregrin*.  As with *fence* - the following helper script first deploys *sheepdog* and *peregrine* services alongside *gdcapi*, and updating the reverse proxy to using the new services is a separate step
```
$ echo You probably need to re-apply the 00configmap.yaml with the dictionary_url variable
$ kubectl apply -f 00configmap.yaml
$ kubectl get configmaps/global -o=jsonpath='{.data.dictionary_url}'
$ bash ~/cloud-automation/tf_files/configs/kube-setup-sheepdog.sh
$ bash ~/cloud-automation/tf_files/configs/kube-setup-peregrine.sh
$ echo verify sheepdog and peregrine are healthy 
$ kubectl get pods; kubectl logs ...
$ kubectl apply -f services/revproxy/00nginx-config.yaml
$ g3k roll revproxy-deployment
```


### Create secrets
Secret is the way in which Kubernetes uses to manage the confidential information such as `ssh_key`, private setting containing `username`, `password` of a `database`, or a `service`. Run the following command with `SECRET_NAME` is the name of secret entry managed by kubernetes, `OUTPUT_FILE` is the file name that you expect to see in the container, and `PATH_TO_INPUT_FILE` is path to the input of that secret.
```
kubectl create secret generic SECRET_NAME --from-file=OUTPUT_FILE=PATH_TO_INPUT_FILE
```

### Update secrets or configMaps
To update a secret or config map, you can delete and recreate it.
```
kubectl delete configmap fence
kubectl create configmap fence --from-file=apis_configs/user.yaml
```

There is currently no way for deployments to recognize that a secret or configmap is updated, but you can enforce a rolling update by doing a patch:
```
kubectl patch deployment $deployment_name -p   "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"

```
It's easier to just use the `g3k` helper function - which should already be added to the shell on a common's k8s provisioner VM:
```
$ g3k roll DEPLOYMENT_NAME
```

### Create deployment/service
A deployment or service is usually defined in a [configuration file](https://github.com/uc-cdis/cloud-automation/blob/master/kube/services/sheepdog/sheepdog-deploy.yaml).

For example, the following command deploys the `sheepdog` deployment to the k8s cluster.
```
g3k roll sheepdog
```

Having the container running, we can access to the container by the following command:
```
kubectl exec -ti $(g3k pod sheepdog) -c CONTAINER_NAME /bin/bash
```

We can also retrieve all the log traces from the container to the pod by:
```
kubectl logs $(g3k pod sheepdog)
```
If you want to keep watching logs for debugging, do:
```
kubectl logs --tail=20 -f $(g3k pod sheepdog)
```

Use `g3k roll SERVICENAME` to update a running deployment. Set `save-config` flag to `true` if the configuration of current object is intended to save in its annotation.

### Mount secrets to container
Secrets are passed to container in the initial phase by mounting as a volume. We can include the mounted secrets into the definition file as [this example](https://github.com/uc-cdis/cloud-automation/blob/master/kube/services/fence/fence-deploy.yaml#L25-L28)

In this example, we want the `local_settings.py` to be located in the same directory with running script. We need to specify two keys (`mountPath` and `subPath`) in each entry of `volumeMounts`. In particular, `mountPath` is the fullpath contains also the name of file, while `subPath` is the file name.

## Expose a service internally with DNS
Domain name should be used to point to a service. Domain name is only recognized at the Pod level, not the Node level.  It means that we need to access to either pod or container to see other container/pod by its domain name.

## Expose a service externally
Currently services are exposed via NodePort since that requires minimal overhead and we are not using a huge cluster that needs load balance. We setup the NodePort and open this port in the security group inbound rule, then we have a reverseproxy outside of the kube cluster which proxy all traffics to services.

## SSL certs
The `cloud_automation/tf_files/configs/kube-certs.sh` script generates a SSL cert using the k8s cluster certificate
authority (kube-aws saves CA keys in the `./credentials` folder on the k8s provisioner under `~/${vpc_name}`) 
for every CDIS service found by
`grep -h 'name:' ./services/*/*service.yaml` (ie. `cloud_automation/kube/services/...`) 
when run on the k8s provisioner in the `~/${vpc_name}` folder, and creates k8s secrets for the service's SSL service certificate and key,
and the CA certificate.  

At any time you can run `bash ~/cloud-automation/tf_files/configs/kube-setup-certs.sh VPC_NAME` on the k8s provisioner
to create certificates and secrets for any services that do not already have a certificate in `~/VPC_NAME/credentials/`.
The `kube-services.sh` script also runs `kube-certs.sh` (kube-certs is actually embedded in kube-services) when setting up
the Gen3 k8s resources the first time.

The k8s deployment (yaml definition) associated with a service "BLA" can be extended to mount the SSL secret
associated with the service with configuration like this:
```

volumes:
    - name: cert-volume
        secret:
        secretName: "cert-BLA-service"
    - name: ca-volume
        secret:
        secretName: "service-ca"

...
volumeMounts:
    - name: "cert-volume"
        readOnly: true
        mountPath: "/mnt/ssl/service.crt"
        subPath: "service.crt"
    - name: "cert-volume"
        readOnly: true
        mountPath: "/mnt/ssl/service.key"
        subPath: "service.key"
    - name: "ca-volume"
        readOnly: true
        mountPath: "/mnt/ssl/cdis-ca.crt"
        subPath: "ca.pem"

```

A container running client code that communicates with a service over SSL should add the CA certificate to the container's trust store (so the client will accept that the service has a valid SSL endpoint) following a procedure similar to [this](https://askubuntu.com/questions/645818/how-to-install-certificates-for-command-line) depending on the nature of the container's image.

## Upgrade kubernetes
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

## Accessing kubernete dashboard
To access the kubernete api/ui, you can start a proxy on the kube provisioner VM:
```
kubectl proxy --port 9090
```
Then you can do ssh port forward from your laptop:
```
ssh -L9090:localhost:9090 -N kube_provisioner_vm
```

## Setting up users and roles

The kube/services/workspace/deploy_workspace.sh script creates a k8s 'worker' user and kubeconfig authenticated via a client certificate
that has basic access to the 'workspace' namespace.  The script and accompanying workspace/*.yaml files
illustrate how we can setup a role with limitted access to the k8s cluster for doing things like deploying jupiter notebooks
onto the cluster or whatever.  The kube-services.sh does not run the workspace/ script by default, but you can
run it at any time to create the worker user (and accomponying certificate, role, kubeconfig, ...) like this
(assuming the KUBECONFIG environment is properly initialized):
```
cd ~/VPC_NAME
bash services/workspace/deploy_workspace.sh
```

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
#### [fence](https://github.com/uc-cdis/fence)
The authentication and authorization provider.
#### [sheepdog](https://github.com/uc-cdis/sheepdog/)
API for submitting data model that stores the metadata for this cluster.
#### [peregrine](https://github.com/uc-cdis/peregrine/)
API for querying graph data model that stores the metadata for this cluster.
#### [indexd](https://github.com/LabAdvComp/indexd)
ID service that tracks all data blobs in different storage locations
#### [data-portal](https://github.com/uc-cdis/data-portal)
Portal to browse and submit metadata.
#### [kafka](https://github.com/uc-cdis/kubernetes-kafka)
Kafka cluster that support different data streams for the system.
#### [elk](https://github.com/uc-cdis/kubernetes-elk)
Elasticsearch-Logstash-Kibana pod for log aggregation using filebeat.

# bash functions

There are some helper functions in [kubes.sh](https://github.com/uc-cdis/cloud-automation/blob/master/kube/kubes.sh) for k8s related operations.

### roll
`g3k roll $DEPLOYMENT_NAME` to let k8s recycle pods when there is no change.

### get_pod
`g3k get_pod $DEPLOYMENT_SUBSTRING` get one of the pods' name for a deployment, this is handy when you want to just run a command on one pod, eg:
`kubectl exec $(get_pod gdcapi) -c gdcapi ls`.

### update_config
`g3k update_config $CONFIG_NAME $CONFIG_FILE` this will delete old configmap and create new configmap with updated content

### run_job

```
ubuntu@ip-172-16-36-26:~$ g3k update_config fence planxplanetv1/apis_configs/user.yaml 
configmap "fence" deleted
configmap "fence" created

ubuntu@ip-172-16-36-26:~$ g3k runjob useryaml
job "useryaml" deleted
job "useryaml" created
```

### help

```
ubuntu@ip-172-16-36-26:~$ g3k help
  
  Use:
  g3k COMMAND - where COMMAND is one of:
    help
    jobpods JOBNAME - list pods associated with given job
    joblogs JOBNAME - get logs from first result of jobpods
    pod PATTERN - grep for the first pod name matching PATTERN
    pods PATTERN - grep for all pod names matching PATTERN
    replicas DEPLOYMENT-NAME REPLICA-COUNT
    roll DEPLOYMENT-NAME
      Apply a superfulous metadata change to a deployment to trigger
      the deployment's running pods to update
    runjob JOBNAME 
     - JOBNAME also maps to cloud-automation/kube/services/JOBNAME-job.yaml
    update_config CONFIGMAP-NAME YAML-FILE
```
