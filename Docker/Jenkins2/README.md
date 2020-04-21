# Jenkins 2 (aka: k8s-jenkins-master)

Jenkins2 is installed through a Helm chart whose tarball (gen3-jenkins-1.8.0.tgz) has been uploaded to s3://cdis-terraform-state/Jenkins2Backup/

The `jenkins-master-deployment.yaml` is kept here just for reference (TODO: repackage tarball and re-upload every time the chart template is modified).

Once both the Helm Chart tarball and the `.values` files are copied to the target Admin VM (that contains a `kubectl` ready to manage a k8s cluster with `tiller` installed), this new Jenkins should be installed/deployed with the following command:

```
gen3 arun helm install gen3-jenkins-1.8.0.tgz --values jenkins.values --name k8sjenkins
```
