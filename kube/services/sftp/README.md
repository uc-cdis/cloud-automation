## SFTP
SFTP server for testing. SFTP runs in a separate namespace called `sftp`. You need to switch to the new namespace when running kubectl. The new namespace require another AWS Certificate.

### Run sftp service
- kubectl config set-context $(kubectl config current-context) --namespace=sftp
- kubectl apply -f 00configmap.yaml
- kubectl apply -f services/sftp/sftp-config.yaml
- password=$(base64 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32)
- kubectl create secret generic sftp-secret --from-literal=dbgap-key=$password
- kubectl apply -f services/sftp/sftp-deploy.yaml
- ./apply_service
- kubectl get services -o wide
- update Route53 Hosted Zones point to the link gotten from the previous command
