# DevOps Jenkins (aka: gen3-devops-jenkins-master)

DevOps Jenkins is installed through a Helm chart whose tarball (devops-jenkins-1.8.0.tgz) has been uploaded to s3://cdis-terraform-state/DevOpsJenkinsBackup/

The `gen3-devopsjenkins-master-deployment.yaml` is kept here just for reference with the initial bootstrapping password redacted. This is used for the very first installation only and then further Security configuration is applied once the root admin logs in and creates new users according to the expected security matrix.
(TODO: repackage tarball and re-upload every time the chart template is modified).

Once both the Helm Chart tarball and the `.values` files are copied to the target Admin VM (that contains a `kubectl` ready to manage a k8s cluster with `tiller` installed), this new Jenkins should be installed/deployed with the following command:

```
gen3 arun helm install devops-jenkins-1.8.0.tgz --values devops-jenkins.values --name gen3DevOpsJenkins
```
