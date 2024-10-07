# The webhook needs a valid cert to work, so we need to create one for the webhook and the deployment to use

cat <<EOF > csr.conf
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[ dn ]
CN = node-affinity-daemonset.kube-system.svc

[ v3_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = daemonset-node-affinity
DNS.2 = node-affinity-daemonset.kube-system
DNS.3 = node-affinity-daemonset.kube-system.svc
DNS.4 = node-affinity-daemonset.kube-system.svc.cluster.local

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = daemonset-node-affinity
DNS.2 = node-affinity-daemonset.kube-system
DNS.3 = node-affinity-daemonset.kube-system.svc
DNS.4 = node-affinity-daemonset.kube-system.svc.cluster.local
EOF


openssl req -new -nodes -x509 -newkey rsa:2048 -keyout server.key -out server.crt -days 365 -config csr.conf -extensions v3_ext

kubectl create secret tls webhook-certs --cert=server.crt --key=server.key -n kube-system

## This will make the base64 for your webhook.yaml file

cat server.crt | base64 | tr -d '\n'


### TODO

Use cert-manager to create the cert for the webhook
