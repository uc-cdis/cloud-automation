#!/bin/bash
#
# Generate the certs for the various Gen3 services, and
# register them as secrets with k8s.
#
# Note that kube.tf cat's this file into kube-services.sh,
# but can also run this standalone if the environment is
# properly configured.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

if [[ -n "$JENKINS_HOME" ]]; then
  echo "Jenkins skipping service certificate setup: $JENKINS_HOME"
  exit 0
fi

mkdir -p "$(gen3_secrets_folder)/credentials/"

cd "$(gen3_secrets_folder)"

if [[ ! -f "$(gen3_secrets_folder)/credentials/ca.pem" && ! -f "$(gen3_secrets_folder)/credentials/ca-key.pem" ]]; then
  echo "Certificate authority not present under $(gen3_secrets_folder)/credentials"
  echo "Creating self signed certificate"
  #openssl genrsa -out "credentials/ca-key.pem" 2048
  SUBJ="/countryName=US/stateOrProvinceName=IL/localityName=Chicago/organizationName=CDIS/organizationalUnitName=Software/commonName=cdis.uchicago.edu/emailAddress=cdis@uchicago.edu"
  #openssl req -x509 -new -nodes -key credentials/ca-key.pem -sha256 -days 1024 -out credentials/ca.pem -subj "$SUBJ"
  openssl req -new -x509 -nodes -extensions v3_ca -keyout credentials/ca-key.pem -out credentials/ca.pem -days 3650 -subj "$SUBJ"
fi

if [[ ! -f "./credentials/openssl.cnf" ]]; then
  (
    cd credentials
    mkdir -p CA/newcerts
    touch CA/index.txt
    echo 1000 > CA/serial
    cat > openssl.cnf <<EOM
[ ca ]
# man ca
default_ca = CA_default

[ CA_default ]
# Directory and file locations.
dir             = $(gen3_secrets_folder)/credentials              # Where everything is kept
new_certs_dir   = \$dir/CA/newcerts
database        = \$dir/CA/index.txt     # database index file.
certificate     = \$dir/ca.pem           # The CA certificate
serial          = \$dir/CA/serial        # The current serial number
private_key     = \$dir/ca-key.pem       # The private key

# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha256
preserve          = no
policy            = policy_strict

[ policy_strict ]
# The root CA should only sign intermediate certificates that match.
# See the POLICY FORMAT section of 'man ca'.
countryName             = optional
stateOrProvinceName     = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ server_cert ]
# Extensions for server certificates ('man x509v3_config').
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[ crl_ext ]
# Extension for CRLs ('man x509v3_config').
authorityKeyIdentifier=keyid:always

EOM

  )
fi

#
# create SSL certs for all our services ...
#
service_list=$(grep -h 'name:' "${GEN3_HOME}"/kube/services/*/*service.yaml | grep -service | sed 's/^\s*//' | sed 's/\s*$//' | sort -u  | awk '{ print $2 }')
if ! g3kubectl get secret service-ca > /dev/null 2>&1; then
  g3kubectl create secret generic "service-ca" --from-file=ca.pem=credentials/ca.pem
fi
for name in $service_list external; do
    if !([[ -f "credentials/${name}.crt" && -f "credentials/${name}.key" ]]); then
      DOMAIN="${name}"   # k8s internal DNS domain ...
      if [[ "$name" == "external" ]]; then
        # 
        # Self signed cert for external clients.
        # Useful for testing until a real cert is available ...
        #
        DOMAIN="$(g3kubectl get configmap global -o json | jq -r '.data["hostname"]')"
      fi
      SUBJ="/countryName=US/stateOrProvinceName=IL/localityName=Chicago/organizationName=CDIS/organizationalUnitName=Software/commonName=${DOMAIN}/emailAddress=cdis@uchicago.edu"
      echo "Generating certificate for $name"
      openssl genrsa -out "credentials/$name.key" 2048
      openssl req -new -key "credentials/$name.key" -out "credentials/$name.csr" -subj "$SUBJ"
      #openssl x509 -req -in "credentials/$name.csr" -CA credentials/ca.pem -CAkey credentials/ca-key.pem -CAcreateserial -out "credentials/${name}.crt" -days 500 -md sha256
      openssl ca -batch -in "credentials/$name.csr" -config credentials/openssl.cnf -extensions server_cert -days 375 -notext -out "credentials/${name}.crt"
    fi
    # may need to create the secret in a different namespace ...
    if ! g3kubectl get secrets "cert-$name" > /dev/null 2>&1; then
      g3kubectl create secret generic "cert-$name" "--from-file=service.crt=credentials/${name}.crt" "--from-file=service.key=credentials/${name}.key"
    fi
done

gen3 secrets commit "saving new TLS certs"
