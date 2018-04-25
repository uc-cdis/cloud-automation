# TL;DR

Templates for deploying `gen3` services to a kubernetes cluster.
The `g3k` helper scripts merge these templates with data
from the [cdis-manifest](https://github.com/uc-cdis/cdis-manifest).
The g3k helpers also automate the creation of missing secrets and configmaps
(if `~/${vpc_name}_output/creds.json` and similar files are present.
These tools are currently only available on the [CSOC adminvm](https://github.com/uc-cdis/cdis-wiki/blob/master/ops/CSOC_Documentation.md) 
associated with a commons.

## Setup

Add the following to `~/.bashrc` (should also work with zsh):
```
export vpc_name="VPC_NAME"
source cloud_automation/kubes.sh
```

## Common Tasks

```
$ g3k help
  
  Use:
  g3k COMMAND - where COMMAND is one of:
    backup - backup home directory to vpc's S3 bucket
    devterm - open a terminal session in a dev pod
    help
    jobpods JOBNAME - list pods associated with given job
    joblogs JOBNAME - get logs from first result of jobpods
    pod PATTERN - grep for the first pod name matching PATTERN
    pods PATTERN - grep for all pod names matching PATTERN
    psql SERVICE 
       - where SERVICE is one of sheepdog, indexd, fence
    replicas DEPLOYMENT-NAME REPLICA-COUNT
    roll DEPLOYMENT-NAME
      Apply the current manifest to the specified deployment - triggers
      and update in most deployments (referencing GEN3_DATE_LABEL) even 
      if the version does not change.
    runjob JOBNAME 
     - JOBNAME also maps to cloud-automation/kube/services/JOBNAME-job.yaml
    testsuite
    update_config CONFIGMAP-NAME YAML-FILE
```

There are some helper functions in [kubes.sh](https://github.com/uc-cdis/cloud-automation/blob/master/kube/kubes.sh) for k8s related operations.

### roll
`g3k roll $DEPLOYMENT_NAME` updates the deployed pods to the 
docker image currently referenced by `cdis-manifest` - 
forces the pod to update even if the image tag has not changed

ex: `g3k roll fence`

Also, `g3k roll all` rolls all services in order, and creates missing
secrets and configuration if the `~/${vpc_name}_output/creds.json` and
similar files are present.

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

