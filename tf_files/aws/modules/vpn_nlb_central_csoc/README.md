## DESCRIPTION

A centralised NLB set-up for VPN will be installed in the CSOC account. This is going to be a centralised VPN set-up. We plan to set-up different VPN set-ups for different environments like prod, qa and dev


## MOTIVATION

There are two major driving force for implementing the VPN cluster set-up:

1) Currently, there is a single VM installed as a OpenVPN server. All the users connects to that OpenVPN server and can access the adminVMs in CSOC via which they can access the data commons. A VPN cluster behind the NLB is going to provide a robust VPN system. All the keys, certs will be backed up securely to a S3 and can be retrieved as and when required. It will be quick to launch a new VPN cluster in case the VM goes down. It will also take care of AZ failure.
2) Currently, all the adminVMs (prod, dev and qa) can be accessed by anyone who is connected to the current CSOC VPN. In fact on a CSOC VPN can access anything in the CSOC VPC (provided there keys are there) With the VPN cluster we have an option of having separate VPN system for separate environment. This is done by pushing appropriate routes to the VPN client machine and having the required ip table rules on the VPN server itself.

## SET-UP

To launch a vpn-nlb central set-up, we run the following from the csoc master admin VM

```gen3 workon csoc <vpnnlbname>_vpnnlbcentral```

This launches a NLB with a target group pointing to the VM running  VPN service. Listeners and target groups corresponding to ```port 1194```, ```port 443``` and  ```port 22```  are created to handle VPN traffic, HTTPS and SSH traffic respectively. Currently, the autoscaling group has a desired capacity of 1, hence at any point of time, we expect a cluster of one VM. This is a limitation with the NLB set-up as we do not have a stickiness feature for NLB and stickiness is a requirement for multiple VPN access servers behind a load balancer. However, we expect a single VPN VM sufficient for our requirement.


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

3. Ask user to get rid of current vpn client config/set-up/2FA and rerun the .ovpn and 2FA as received in the email


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


## Overview

Once you workon the workspace, you may want to edit the config.tfvars accordingly.

There are mandatory variables, and there are a few other optionals that are set by default in the variables.tf file, but you could change them accordingly.

Ex.
```
env_vpn_nlb_name             = "occ-dev-vpn"
env_cloud_name               = "occ-dev-vpn.occ-pla.net"
env_vpc_id                   = "vpc-0f8c7b18c1596fd73"
env_pub_subnet_routetable_id = "rtb-064af9f9b08de3dd8"
csoc_planx_dns_zone_id       = "Z043146513PFJKDJS33N1"
csoc_vpn_subnet              = "192.168.250.0/24"
csoc_vm_subnet               = "192.168.16.0/24"
vpn_server_subnet            = "192.168.17.0/24"
image_name_search_criteria   = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-\*"
ssh_key_name                 = "fauzi@uchicago.edu"
csoc_account_id              = "504226487987"
organization_name            = "occ"
bootstrap_script             = "vpnvm_ubuntu18.sh"
cwl_group_name               = "occ-dev-vpn.planx-pla.net_log_group"

```

## Variables

### Required Variables

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| csoc_vpn_subnet | | string | |
| csoc_vm_subnet | Subnet where the vpn server will be | string | |
| vpn_server_subnet | Subnet that the service will allocate to clients | string | |



### Optional Variables


| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| env_vpc_id | VPC ID where where the instances will be. | string | "vpc-e2b51d99" |
| env_vpn_nlb_name | Name for the instances. | string | "csoc-vpn-nlb" |
| env_cloud_name | This one will be used as hostname. | string | "planxprod" |
| ami_account_id | AWS account id to use for AMIs look up. | strint | "099720109477" |
| image_name_search_criteria | AMI name intended to be used for the VM. deployment | string | "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-2018*" |
| env_pub_subnet_routetable_id | Route table id used for public access.  | string | "rtb-1cb66860" |
| csoc_planx_dns_zone_id | Route53 host zone id to use for adding the vpn hostname. | string | "ZG153R4AYDHHK" |
| ssh_key_name | Key to access the VM. It must exist already in the account. | string | "rarya_id_rsa" |
| bootstrap_path | Path where the bootstrap scrip is. | string | "cloud-automation/flavors/vpn_nlb_central/" |
| bootstrap_script | The actual bootstrap script in the path set above| string | "vpnvm.sh" |
| organization_name | For tagging purposes | string | "Basic Service" |
| extra_vars | Additional variables for the bootstrap script. Ex. `key=value` | list | [] |
| authorized_keys | This file content will be appended to the users .ssh/authorized_keys | string | "files/authorized_keys/ops_team" |
| cwl_group_name | Logs group name for instances logs | string | "csoc-prod-vpn.planx-pla.net_log_group" |
| branch | For testing purposes | string | "master" |


## Outputs 

| Name | Description |
|------|-------------|
| vpn_nlb_dns_name | DNS name placed in the Route53 hosted zone specified as variable |


