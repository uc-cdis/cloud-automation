#!/bin/bash
#
# Reset CI env pool to put quarantined environments back in rotation
#
# vpc_name="qaplanetv1"
# 52   1   *   *   *    (if [ -f $HOME/cloud-automation/files/scripts/ci-env-pool-reset.sh ]; then bash $HOME/cloud-automation/files/scripts/ci-env-pool-reset.sh; else echo "no ci-env-pool-reset.sh"; fi) > $HOME/ci-env-pool-reset.log 2>&1

export GEN3_HOME="$HOME/cloud-automation"
export vpc_name="${vpc_name:-"qaplanetv1"}"
export KUBECONFIG="${KUBECONFIG:-"$HOME/${vpc_name}/kubeconfig"}"

if [[ ! -f "$KUBECONFIG" ]]; then
  KUBECONFIG="$HOME/Gen3Secrets/kubeconfig"
fi

if ! [[ -d "$HOME/cloud-automation" && -d "$HOME/cdis-manifest" && -f "$KUBECONFIG" ]]; then
  echo "ERROR: this does not look like a QA environment"
  exit 1
fi

PATH="${PATH}:/usr/local/bin"

if [[ -z "$USER" ]]; then
  export USER="$(basename "$HOME")"
fi

source "${GEN3_HOME}/gen3/gen3setup.sh"

cat - > jenkins-envs-services.txt <<EOF
jenkins-genomel
jenkins-niaid
jenkins-blood
jenkins-brain
jenkins-dcp
jenkins-new
EOF

cat - > jenkins-envs-releases.txt <<EOF
jenkins-genomel
jenkins-niaid
jenkins-blood
jenkins-brain
jenkins-dcp
jenkins-new
EOF

aws s3 cp jenkins-envs-services.txt s3://cdistest-public-test-bucket/jenkins-envs-services.txt
aws s3api put-object-acl --bucket cdistest-public-test-bucket --key jenkins-envs-services.txt --acl public-read
aws s3 cp jenkins-envs-releases.txt s3://cdistest-public-test-bucket/jenkins-envs-releases.txt
aws s3api put-object-acl --bucket cdistest-public-test-bucket --key jenkins-envs-releases.txt --acl public-read
