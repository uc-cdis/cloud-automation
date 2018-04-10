#!/bin/bash
#
# Generate the certs for the various Gen3 services, and
# register them as secrets with k8s.
#
# Note that kube.tf cat's this file into kube-services.sh,
# but can also run this standalone if the environment is
# properly configured.
#

set -e

_KUBE_SETUP_CERTS=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
# Jenkins friendly
export WORKSPACE="${WORKSPACE:-$HOME}"
export GEN3_HOME="${GEN3_HOME:-$(cd "${_KUBE_SETUP_CERTS}/../.." && pwd)}"

if [[ -z "$_KUBES_SH" ]]; then
  source "$GEN3_HOME/kube/kubes.sh"
fi # else already sourced this file ...

vpc_name=${vpc_name:-$1}
if [ -z "${vpc_name}" ]; then
   echo "Usage: bash kube-setup-fence.sh vpc_name"
   exit 1
fi

if [[ ! -f "${WORKSPACE}/${vpc_name}/credentials/ca.pem" ]]; then
  echo "Certificate authority not present - cannot create certs: ${WORKSPACE}/${vpc_name}/credentials"
  exit 1
fi 

cd "${WORKSPACE}/${vpc_name}"

#
# create SSL certs for all our services ...
#
service_list=$(grep -h 'name:' "${GEN3_HOME}"/kube/services/*/*service.yaml | grep -service | sed 's/^\s*//' | sed 's/\s*$//' | sort -u  | awk '{ print $2 }')
if ! g3kubectl get secret service-ca > /dev/null 2>&1; then
  g3kubectl create secret generic "service-ca" --from-file=ca.pem=credentials/ca.pem
fi
for name in $service_list; do
    if !([[ -f "credentials/${name}.crt" && -f "credentials/${name}.key" ]]); then
      DOMAIN="${name}"   # k8s internal DNS domain ...
      SUBJ="/countryName=US/stateOrProvinceName=IL/localityName=Chicago/organizationName=CDIS/organizationalUnitName=Software/commonName=${DOMAIN}/emailAddress=cdis@uchicago.edu"
      echo "Generating certificate for $name"
      openssl genrsa -out "credentials/$name.key" 2048
      openssl req -new -key "credentials/$name.key" -out "credentials/$name.csr" -subj "$SUBJ"

      openssl x509 -req -in "credentials/$name.csr" -CA credentials/ca.pem -CAkey credentials/ca-key.pem -CAcreateserial -out "credentials/${name}.crt" -days 500
    else
      echo "Certificate already exists credentials/${name}.crt"
    fi
    # may need to create the secret in a different namespace ...
    if ! g3kubectl get secrets "cert-$name" > /dev/null 2>&1; then
      g3kubectl create secret generic "cert-$name" "--from-file=service.crt=credentials/${name}.crt" "--from-file=service.key=credentials/${name}.key"
    fi
done
