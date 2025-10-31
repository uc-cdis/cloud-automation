# Jenkins 2 (aka: k8s-jenkins-master)

Jenkins2 is installed through a Helm chart whose tarball (gen3-jenkins-1.8.0.tgz) has been uploaded to s3://cdis-terraform-state/Jenkins2Backup/

The `jenkins-master-deployment.yaml` is kept here just for reference (TODO: repackage tarball and re-upload every time the chart template is modified).

Once both the Helm Chart tarball and the `.values` files are copied to the target Admin VM (that contains a `kubectl` ready to manage a k8s cluster with `tiller` installed), this new Jenkins should be installed/deployed with the following command:

```
gen3 arun helm install gen3-jenkins-1.8.0.tgz --values jenkins.values --name k8sjenkins
```

# Troubleshooting

The CI pipeline and utility jobs in Jenkins2 will only work if the following setup is in place. It requires:
- Service Accounts (`k8sjenkins` is created by the helm chart)
```
$ kc get sa | grep jenkins
jenkins-service                                    1         308d
k8sjenkins                                         1         286d
```
- Roles (`k8sjenkins-schedule-agents` is created by the helm chart)
```
$ kc get roles | grep jenkins
k8sjenkins-schedule-agents   25h
```
- RoleBindings (`k8sjenkins-schedule-agents` is created by the helm chart)
```
$ kc get rolebindings | grep jenkins
k8sjenkins-schedule-agents   25h
```
- Network Policies (Not created by the Helm Chart)
```
$ kc get networkpolicies | grep -E "jenkins|selenium"
k8sjenkins-agent-master-policy   jenkins=slave                                                                                     22h
k8sjenkins-agent-policy          app.kubernetes.io/component=k8s-jenkins-master-deployment,app.kubernetes.io/instance=k8sjenkins   22h
netpolicy-jenkins                app=jenkins                                                                                       308d
selenium-hub-nodes-policy        app=selenium-hub                                                                                  146m
```

# TODO

Integrate required network policies into the helm chart

Recently, the need for network policies in qaplanetv2 has been reinforced, hence this requires additional network policies for:
- The 2-way communication between the Jenkins master and the ephemeral agents/pods.
- The communication with the Selenium hub
