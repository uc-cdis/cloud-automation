## Reverse proxy
Right now all services external facing go through this reverse proxy as they serve under subdirectories of the same domain name

### Run reverse proxy
- create a cert in AWS Certificate Manager, this will require the admin for the domain approve it through email
- g3kubectl apply -f 00nginx-config.yaml
- g3kubectl apply -f services/revproxy/revproxy-deployment.yaml
- ./apply_service
- change the load balancer settings in AWS to use "Listeners->Cipher for port 443->ELBSecurityPolicy-TLS-1-2-2017-01" [issue 151](https://github.com/kubernetes/kubernetes/issues/43744)
- update DNS to point to your ELB
