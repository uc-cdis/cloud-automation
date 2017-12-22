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

#
# This is a little goofy.
# The script assumes ~/vpc_name exists with
# a kubeconfig file and ./services/ folder
#
if [ ! -z "${vpc_name}" ]; then
  if [ ! -f ~/"${vpc_name}/kubeconfig" ]; then
    echo "ERROR: expected ~/${vpc_name}/kubeconfig to exist - bailing out"
    exit 1
  fi
  cd ~/"${vpc_name}"
  export KUBECONFIG=~/"${vpc_name}/kubeconfig"
fi

if [ ! -d ./services ]; then
  echo "ERROR: No ./services/ folder - launch from ~/VPC_NAME/ - bailing out"
  exit 1
fi

if [ ! -f ./credentials/ca.pem ]; then
  echo "ERROR: No ./credentials/ca.pem certificate authority - launch from ~/VPC_NAME/ - bailing out"
  exit 1
fi

if [ -z "${KUBECONFIG}" ]; then
  if [ -f ./kubeconfig ]; then
    export KUBECONFIG=./kubeconfig
  else
    echo "ERROR: KUBECONFIG not configured - bailing out"
    exit 1
  fi
fi

#
# create SSL certs for all our services ...
#
service_list=$(grep -h 'name:' services/*/*service.yaml | grep -service | sed 's/^\s*//' | sed 's/\s*$//' | sort -u  | awk '{ print $2 }')
if ! kubectl get secret service-ca > /dev/null 2>&1; then
  kubectl create secret generic "service-ca" --from-file=ca.pem=credentials/ca.pem
fi
for name in $service_list; do
    if [ ! -f "credentials/${name}.crt" ]; then
      DOMAIN="${name}.default"   # k8s internal DNS domain ...
      SUBJ="/countryName=US/stateOrProvinceName=IL/localityName=Chicago/organizationName=CDIS/organizationalUnitName=Software/commonName=${DOMAIN}/emailAddress=cdis@uchicago.edu"
      echo "Generating certificate for $name"
      openssl genrsa -out "credentials/$name.key" 2048
      openssl req -new -key "credentials/$name.key" -out "credentials/$name.csr" -subj "$SUBJ"

      openssl x509 -req -in "credentials/$name.csr" -CA credentials/ca.pem -CAkey credentials/ca-key.pem -CAcreateserial -out "credentials/${name}.crt" -days 500
      kubectl create secret generic "cert-$name" "--from-file=service.crt=credentials/${name}.crt" "--from-file=service.key=credentials/${name}.key"
    else
      echo "Certificate already exists credentials/${name}.crt"
    fi
done
