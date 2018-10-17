## DESCRIPTION

A centralised NLB set-up for VPN will be installed in the CSOC account. This is going to be a centralised VPN set-up. We plan to set-up different VPN set-ups for different environments like prod,qa and dev


## MOTIVATION

There are two major driving force for implementing the VPN cluster set-up:

1) Currently, there is a single VM installed as a OpenVPN server. All the users connects to that OpenVPN server and can access the adminVMs in CSOC via which they can access the data commons. A VPN cluster befind the NLB is going to provide a robust VPN system. All the keys,certs will be backed up securely to a S3 and can be restrieved as and when required.It will be quick to launch a new VPN cluster in case the VM goes down. It will also take care of AZ failure.
2) Currently, all the adminVMs (prod,dev and qa) can be accessed by anyone who is connected to the current CSOC VPN.Infact on a CSOC VPN can access anything in the CSOC VPC (provided there keys are there) With the VPN cluster we have an option of having separate VPN system for seperate environment. This is done by pushing appropriate routes to the VPN client machine and having the required iptable rules on the VPN server itself.

## SET-UP

To launch a vpn-nlb central set-up, we run the following from the csoc master admin VM 

```gen3 workon csoc <vpnnlbname>_vpnnlbcentral```

This launches a NLB with a target group pointing to the VM running  VPN service. Listeners and target groups correspodning to ```port 1194```, ```port 443``` and  ```port 22```  are created to handle VPN traffic, HTTPS and SSH traffic respectively. Currently, the autoscaling group has a desired capacity of 1, hence at any point of time, we expect a cluster of one VM. This is a limitation with the NLB set-up as we do not have a stickiness feature for NLB and stickiness is a requirement for multiple VPN access servers behind a load balancer. However, we expect a single VPN VM sufficient for our requirement. 


## IP SCHEMA

## csoc prod-vpn

```Hostname (FQDN) - csoc-prod-vpn.planx-pla.net```

```OpenVPN Network (csoc_vpn_subnet) - 192.168.1.0/24```

```VM network at CSOC for which the routes need to be pused (csoc_vm_subnet) -  10.128.2.0/24```

```VPN server cluster network at AWS (vpn_server_subnet) - 10.128.5.0/25```


## csoc dev-vpn

```Hostname (FQDN) - csoc-dev-vpn.planx-pla.net```

```OpenVPN Network (csoc_vpn_subnet) - 192.168.2.0/24```

```VM network at CSOC for which the routes need to be pused (csoc_vm_subnet) -  10.128.7.0/24```

```VPN server cluster network at AWS (vpn_server_subnet) - 10.128.5.128/25```



## CERTS RENEWAL 

## Renewing the OpenVPN server certs
1. Create a directory to save the current certs
```mkdir -p /etc/openvpn/easy-rsa/keys/oldkeys.$(hostname).$(date +%F)```

2. Copy the current certs to the directory
```cp /etc/openvpn/easy-rsa/keys/$(hostname)* /etc/openvpn/easy-rsa/keys/oldkeys.$(hostname).$(date +%F)/```

3. Source the settings
```source /etc/openvpn/bin/settings.sh```

4. Revoke the server cert 
```$EASY_RSA/revoke-full $(hostname)```

5. Run the pki tool
```$EASY_RSA/pkitool --server $(hostname)```

6. Restart the vpn service
```systemctl restart openvpn```

7. Make sure the openvpn client can connect to the VPN from your user. If yes, push the changes to the S3
```/etc/openvpn/openvpn_management_scripts/ push_to_s3.sh```

## Renewing the OpenVPN client certs
1. Revoke the user
```/etc/openvpn/openvpn_management_scripts/revoke_user.sh <username>```

2. Send the email
```/etc/openvpn/openvpn_management_scripts/send_email.sh /root/<user.csv>```

3. Ask user to get rid of curent vpn client config/set-up/2FA and rerun the .ovpn and 2FA as received in the email


## Renewing the Lighttpd server certs

0. Login to the VPN server behind the load balancer

1. Generate a new CSR as cert.csr

```openssl req  -subj '/C=US/ST=IL/L=Chicago/O=CDIS' -new -key /root/cert.key -out /root/cert.csr```

2. Take a backup of the existing cert.pem server.pem

```mv /root/cert.pem /root/cert.old.$(date +%F).pem```

```mv /root/server.pem /root/server.old.$(date +%F).pem```

3. Create the new cert.pem 

```openssl x509 -req -days 365 -in /root/cert.csr -signkey /root/cert.key -out /root/cert.pem```

4. Concatenate the cert.key and cert.pem and create a new server.pem

```cat /root/cert.key /root/cert.pem > /root/server.pem```

5. Check for the end date on server.pem

```openssl x509 -in /root/server.pem -noout -enddate```

6. Reload the cert for lighttpd

```mv  /etc/lighttpd/certs/server.pem  /etc/lighttpd/certs/server.old.$(date +%F).pem```

```cp /root/server.pem /etc/lighttpd/certs/server.pem```

7. Restart the lighttpd service

```service lighttpd restart```

8. Backup to S3

```/etc/openvpn/bin/push_to_s3.sh```





   

