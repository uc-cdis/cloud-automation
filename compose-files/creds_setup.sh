#!/bin/bash
# Script to setup keys for fence as well as ssl credentials 

# make directories for temporary credentials
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
mkdir -p temp_creds
mkdir -p temp_keys
mkdir -p temp_keys/${timestamp}

# generate private and public key for fence
openssl genpkey -algorithm RSA -out temp_keys/${timestamp}/jwt_private_key.pem \
    -pkeyopt rsa_keygen_bits:2048
openssl rsa -pubout -in temp_keys/${timestamp}/jwt_private_key.pem \
    -out temp_keys/${timestamp}/jwt_public_key.pem


# generate certs for nginx ssl
SUBJ="/countryName=US/stateOrProvinceName=IL/localityName=Chicago/organizationName=CDIS/organizationalUnitName=PlanX/commonName=localhost/emailAddress=cdis@uchicago.edu"
openssl req -new -x509 -nodes -extensions v3_ca -keyout temp_creds/ca-key.pem \
    -out temp_creds/ca.pem -days 365 -subj $SUBJ
if [[ $? -eq 1 ]]; then    
    echo "problem with creds_setup.sh script, refer to compose-services wiki"
    rm -rf temp*
    exit 1
fi


(
    cd temp_creds
    mkdir -p CA/newcerts
    touch CA/index.txt
    echo 1000 > CA/serial
    cat > openssl.cnf <<EOM
[ ca ]
# man ca
default_ca = CA_default
[ CA_default ]
# Directory and file locations.
dir             = temp_creds              # Where everything is kept
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
openssl genrsa -out "temp_creds/service.key" 2048
openssl req -new -key "temp_creds/service.key" \
    -out "temp_creds/service.csr" -subj $SUBJ
openssl ca -batch -in "temp_creds/service.csr" -config temp_creds/openssl.cnf \
    -extensions server_cert -days 365 -notext -out "temp_creds/service.crt" 
