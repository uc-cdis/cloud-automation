#!/bin/bash
#
# This script will create a new gen3 environment from scratch
# to be used in ephemeral CI runs

# TODO: leverage gen3 config-env to *copy* config from existing envs and
# create ephemeral CI environments of any flavours we want (e.g., anvil, va, covid10, heal, etc.)

source ${GEN3_HOME}/gen3/lib/utils.sh
gen3_load "gen3/gen3setup"

# the code below should be atrocious as the fix-it-friday experiment is based on DTSTTCPW

ciEnvName=$1

# TODO: consider a limit of ci envs (save some moola)
# TODO: come up with cronjob to tear down old environments
# Reminder, use the following commands to tear down envs.:
# sudo rm -Rf /home/jenkins-ci-3/ && sudo sed -i '/jenkins-ci-3/d' /etc/passwd && sudo sed -i '/jenkins-ci-3/d' /etc/group && kubectl delete namespace jenkins-ci-3

set -x

# TODO: Step 0
# Make sure qaplanetv1 is healthy
# Create health check mechanism (?)
# Fail fast ( don't create new envs if the source env is broken)

# step 1 - Create new workspace by cloning qaplanetv1
workspaceAlreadyExist=$(g3kubectl get ns | awk '{ print $1 }' | grep -v NAME | grep $ciEnvName)
if [ -z "$workspaceAlreadyExist" ]; then
  gen3 kube-dev-namespace $ciEnvName
else
  echo "this ci env workspace alredy exists..."
fi

# TODO: add a 2nd argument so the operator can pick a flavor of gen3 env (dcp, genomel, blood, niaid, ..)# step 2 - Copy the folder from some existing CI environment
#originalHostname="jenkins-new.planx-pla.net"
#originalK8sNamespace="jenkins-new"
#newHostname="${ciEnvName}.planx-ci.io"
#newK8sNamespace=$ciEnvName

# TODO: Make this more generic
# grep -rl $originalHostname ~/cdis-manifest/$newHostname | xargs sed -i "s/$originalHostname/$newHostname/g"
#cp -R cdis-manifest/jenkins-new.planx-pla.net cdis-manifest/${ciEnvName}.planx-ci.io
#sed -i 's/'$ciEnvName'.planx-pla.net/'$ciEnvName'.planx-ci.io/' cdis-manifest/${ciEnvName}.planx-ci.io/manifests/hatchery/hatchery.json
#sed -i 's/jenkins-new/'$ciEnvName'/' cdis-manifest/${ciEnvName}.planx-ci.io/manifests/hatchery/hatchery.json

#sed -i 's/jenkins-new.planx-pla.net/'$ciEnvName'.planx-ci.io/' cdis-manifest/${ciEnvName}.planx-ci.io/manifest.json
#sed -i 's/jenkins-new/'$ciEnvName'/' cdis-manifest/${ciEnvName}.planx-ci.io/manifest.json

# TODO: Instead of mutating strings in config files and manifests, we need a templetisized source-of-truth
# of all the latest manifest skeleton + sub-manifests (e.g., hatchery, mariner, etc.)
# We need to define such source-of-truth for a proper way to manage our manifests

# Step 2 - Copy artifacts from an existing CI env folder and replace the k8s namespace and hostname references

# TODO: make sure you are running this in qaplanetv<n> (default cluster account)
# whoami == qaplanetv1

newHostname="${ciEnvName}.planx-ci.io"
cp -R ~/cdis-manifest/jenkins-new.planx-pla.net ~/cdis-manifest/${ciEnvName}.planx-ci.io

# get new subdomain
newSubdomain=$(echo $newHostname | cut -d '.' -f 1)
# Update the domain from planx-pla.net to planx-ci.io
grep -rl "planx-pla.net" ~/cdis-manifest/$newHostname | xargs sed -i 's/planx-pla.net/planx-ci.io/g'
# update the subdomain
grep -rl "jenkins-new" ~/cdis-manifest/$newHostname | xargs sed -i 's/jenkins-new/'$newSubdomain'/g'

# we are creating the new env. folder in qaplanetv<n>
# but the folder must exist in its own user space
sudo cp -R ~/cdis-manifest/${ciEnvName}.planx-ci.io /home/${ciEnvName}/cdis-manifest/
# set correct permissions to the new user and its respective home folder (and all sub folders)
sudo chown -R ${ciEnvName} /home/${ciEnvName}/

# Step 3 - apply the ZERO configmap to initialize the config for this new env.
# BEAR IN MIND that the revproxy ARN points to a planx-pla.net ACM certificate
# We need to replace the planx-pla.net cert with a new ARN that corresponds to the planx-ci.io cert

export KUBECTL_NAMESPACE="$ciEnvName"
sudo sed -i 's/planx-pla.net/planx-ci.io/g' /home/${ciEnvName}/Gen3Secrets/00configmap.yaml

# set new planx-ci.io certificate to configmap zero
sudo sed -i 's/\(.*\)revproxy_arn:[[:space:]]\(.*\)/\1revproxy_arn: arn:aws:acm:us-east-1:707767160287:certificate\/47bc0e46-7e92-4b09-81eb-10afb7add907/' /home/${ciEnvName}/Gen3Secrets/00configmap.yaml
RC=$?
if [[ $RC -ne 0 ]]; then
  echo "Certificate ARN was not replaced correctly. Abort..."
  exit 1
fi

# set new planx-ci.io certificate to manifest.json
sudo sed -i 's/\(.*\)"revproxy_arn":[[:space:]]\(.*\)/\1"revproxy_arn": "arn:aws:acm:us-east-1:707767160287:certificate\/47bc0e46-7e92-4b09-81eb-10afb7add907",/' /home/${ciEnvName}/cdis-manifest/${ciEnvName}.planx-ci.io/manifest.json
RC=$?
if [[ $RC -ne 0 ]]; then
  echo "Certificate ARN was not replaced correctly. Abort..."
  exit 1
fi

g3kubectl apply -f /home/${ciEnvName}/Gen3Secrets/00configmap.yaml

# Step 4 - Stand up the new environment
# export BASH_SOURCE="/home/${ciEnvName}/cloud-automation/gen3/bin/kube-roll-all.sh"
  sudo su - ${ciEnvName} -c "export KUBECONFIG=/home/${ciEnvName}/Gen3Secrets/kubeconfig; export GEN3_HOME=/home/${ciEnvName}/cloud-automation && source \"$GEN3_HOME/gen3/gen3setup.sh\"; source ~/.bashrc; gen3 roll all"

# Step 5 - start polling logic to capture the reproxy ELB CNAME
revProxyCheckCounter=0
while [[ -z $(g3kubectl get svc | grep revproxy-service-elb | grep amazonaws.com) ]]; do
  if [[ "$revProxyCheckCounter" -lt 60 ]]; then
    let revProxyCheckCounter+=1
  else
    gen3_log_err "Timed out waiting for revproxy elb"
    exit 1
  fi
  gen3_log_info "Waiting for revproxy elb to start up"
  sleep 10
done
gen3_log_info "Revproxy elb up"

revProxyELBCNAME=$(g3kubectl get svc | grep revproxy-service-elb | awk '{ print $4 }')

aws route53 change-resource-record-sets --hosted-zone-id Z06443771GOMG3K6QGBSI --change-batch '{ "Comment": "Creating new record set for '${ciEnvName}'", "Changes": [ { "Action": "CREATE", "ResourceRecordSet": {"Name": "'${ciEnvName}'.planx-ci.io","Type": "A","AliasTarget": {"HostedZoneId": "Z35SXDOTRQ7X7K","DNSName": "'${revProxyELBCNAME}'.","EvaluateTargetHealth": false}} } ] }'

# Step 6 - start polling logic to make sure the environment is publicly available
newEnvUpAndRunningCheckCounter=0
responseHttpCode=$(curl -L -s -o /dev/null -w "%{http_code}" "https://${ciEnvName}.planx-ci.io")
while [[ $responseHttpCode != 200 ]]; do
  if [[ "$newEnvUpAndRunningCheckCounter" -lt 60 ]]; then
    let newEnvUpAndRunningCheckCounter+=1
  else
    gen3_log_err "Timed out waiting for https://${ciEnvName}.planx-ci.io ..."
    exit 1
  fi
  gen3_log_info "Waiting for https://${ciEnvName}.planx-ci.io"
  sleep 10
done
gen3_log_info "https://${ciEnvName}.planx-ci.io is up. Yay"
