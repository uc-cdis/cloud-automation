# TL;DR

gen3 online automation help available:
* [online](https://github.com/uc-cdis/cloud-automation/blob/master/doc/README.md)
* via `gen3 help filename`

For example - `gen3 help aws` opens `aws.md`

## Frequently used

* [api](./api.md) - indexd-post-folder, access-token, new-program, new-project
* [arun](./arun.md)
* [aws](./aws.md)
* [awsrole](./awsrole.md)
* [awsuser](./awsuser.md)
* [iam-serviceaccount](./iam-serviceaccount.md)
* [devterm](./devterm.md)
* [db](./db.md)
* [dashboard](./dashboard.md)
* [es](./es.md) - elastic search
* [gitops](./gitops.md) - manifest filter, configmaps, history, sync, tagging releases, etc
* [ec2](./ec2.md) - describe, reboot, snapshot
* [job logs|pods|run](./job.md)
* [joblogs](./job.md) - see [job logs](./job.md)
* [jupyter](./jupyter.md) - j-namespace, upgrade
* [klock](./klock.md) - formerly kube-lock/kube-unlock
* [kube-setup-portal](./kube-setup-portal.md)
* [kube-setup-revproxy](./kube-setup-revproxy.md)
* [kube-setup-secrets](./kube-setup-secrets.md)
* [kube-wait4-pods](./kube-wait4-pods.md)
* [maintenance mode](./maintenance.md)
* [psql](./psql.md)
* [random](./random.md)
* [replicas](./replicas.md)
* [reset](./reset.md)
* [roll](./roll.md)
* [runjob](./job.md) - see [job run](./job.md)
* [secrets](./secrets.md)
* [testsuite](./testsuite.md)
* [update_config](./update_config.md)
* [watch](./watch.md)


## Configure services and gitops

* [kube-setup-arborist](./kube-setup-arborist.md)
* [kube-setup-arranger](./kube-setup-arranger.md)
* [kube-setup-aws-es-proxy](./kube-setup-aws-es-proxy.md)
* [kube-setup-google.md](./kube-setup-google.md)
* [kube-setup-fence](./kube-setup-fence.md)
* [kube-setup-fluentd](./kube-setup-fluentd.md)
* [kube-setup-jenkins](./kube-setup-jenkins.md)
* [kube-setup-jupyterhub](./kube-setup-jupyterhub.md)
* [kube-setup-peregrine](./kube-setup-peregrine.md)
* [kube-setup-pidgin](./kube-setup-pidgin.md)
* [waf - webapp firewall](./waf.md)

## Terraform related

* [cd](./terraform/cd.md)
* [ls](./terraform/ls.md)
* [refresh](./refresh.md)
* [status](./status.md)
* [tfplan](./terraform/tfplan.md)
* [tfapply](./terraform/tfapply.md)
* [tform](./terraform/tform.md)
* [tfoutput](./terraform/tfoutput.md)
* [trash](./trash.md)
* [workon](./terraform/workon.md)


## Overview

* [gen3 install and overview](../gen3/README.md)
* [gen3 kube/ yaml template processing](../kube/README.md)
* [arranger configuration](../kube/services/arranger/README.md)
* [tube configuration](../kube/services/tube/README.md)
* [running the arranger dashboard](../kube/services/arranger-dashboard/README.md)
* [canary releases](./canary.md)
* [cloud accounts and access](https://github.com/uc-cdis/cdis-wiki/blob/master/ops/AWS-Accounts.md)
* [commons infrastructure](./terraform/commonsOverview.md)
* [csoc](../CSOC_Documentation.md)
* [csoc vpn](../tf_files/aws/modules/vpn_nlb_central_csoc/README.md)
* [EKS](../tf_files/aws/modules/eks/README.md)
* [utility vm](../tf_files/aws/modules/utility-vm/README.md)
* [explorer infrastructure](https://github.com/uc-cdis/cdis-wiki/blob/master/dev/gen3/data_explorer/README.md)
* [automation for gcp](../tf_files/gcp/commons/README.md)
* [gcp bucket access flows for DCF](https://github.com/uc-cdis/fence/blob/master/docs/additional_documentation/google_architecture.md)
* [authn and authz with fence](https://github.com/uc-cdis/fence/blob/master/README.md)
* [jenkins](../kube/services/jenkins/README.md)
* [jupyterhub configuration](../kube/services/jupyterhub/README.md)
* [logging infrastructure in AWS](../tf_files/aws/modules/common-logging/README.md)
* [log parsing and analytics in AWS](../kube/services/fluentd/README.md)
* [new commons cookbook](../README.md)
* [portal configuration](../kube/services/portal/README.md)
* [portal dev mode](https://github.com/uc-cdis/cdis-wiki/blob/master/dev/Local-development-for-Gen3.md#nginx-installation)
* [reverse proxy configuration](../kube/services/revproxy/README.md)
* [terraform](../tf_files/README.md)
* [network diagram](../README.md#network-diagram)

## Batch Jobs

* [gentestdata-job](../kube/services/jobs/README.md#gentestdata-job)
* [usersync-job](../kube/services/jobs/README.md#usersync-job)
* [dcf google jobs](../kube/services/jobs/README.md#google-jobs)

## More

* [approve_vpcpeering_request](./approve_vpcpeering_request.md)
* [ha-proxy](./ha-squid-migration.md) - Migration from a single squid instance to an HA proxy solution
* [kube-backup](./kube-backup.md)
* [kube-dev-namespace](./kube-dev-namespace.md)
* [kube-extract-config](./kube-extract-config.md)
* [kube-roll-all](./kube-roll-all.md)
* [kube-roll-qa](./kube-roll-qa.md)
* [kube-setup-arborist](./kube-setup-arborist.md)
* [kube-setup-arranger](./kube-setup-arranger.md)
* [kube-setup-autoscaler](./kube-setup-autoscaler.md)
* [kube-setup-aws-es-proxy](./kube-setup-aws-es-proxy.md)
* [kube-setup-certs](./kube-setup-certs.md)
* [kube-setup-google.md](./kube-setup-google.md)
* [kube-setup-fence](./kube-setup-fence.md)
* [kube-setup-fluentd](./kube-setup-fluentd.md)
* [kube-setup-jenkins](./kube-setup-jenkins.md)
* [kube-setup-jupyterhub](./kube-setup-jupyterhub.md)
* [kube-setup-kube-dns-autoscaler](./kube-setup-kube-dns-autoscaler.md)
* [kube-setup-networkpolicy](./kube-setup-networkpolicy.md)
* [kube-setup-peregrine](./kube-setup-peregrine.md)
* [kube-setup-pidgin](./kube-setup-pidgin.md)
* [kube-setup-portal](./kube-setup-portal.md)
* [kube-setup-revproxy](./kube-setup-revproxy.md)
* [kube-setup-roles](./kube-setup-roles.md)
* [kube-setup-secrets](./kube-setup-secrets.md)
* [kube-setup-sftp](./kube-setup-sftp.md)
* [kube-setup-sheepdog](./kube-setup-sheepdog.md)
* [kube-setup-shiny](./kube-setup-shiny.md)
* [kube-setup-spark](./kube-setup-spark.md)
* [kube-setup-tiller](./kube-setup-tiller.md)
* [kube-setup-tube](./kube-setup-tube.md)
* [kube-setup-workvm](./kube-setup-workvm.md)
* [kube-setup-ssjdispatcher](./kube-setup-ssjdispatcher.md)
* [netpolicy](./netpolicy.md) - `kube-setup-networkpolicy` helpers
