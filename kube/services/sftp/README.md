## SFTP
SFTP server for testing

### Run sftp service
- kubectl apply -f services/sftp/sftp-config.yaml
- password=$(base64 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32)
- kubectl create secret generic sftp-secret --from-literal=dbgap-key=$password
- kubectl apply --namespace=sftp -f services/sftp/sftp-deploy.yaml
- ./apply_service
- kubectl get services -o wide
- update Route53 Hosted Zones point to the link gotten from the previous command
