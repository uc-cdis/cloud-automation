#!/bin/bash
aws s3 sync s3://vpn-certs-and-files/WHICHVPN/easy-rsa/ /etc/openvpn/easy-rsa/ || true
#fix perms
for i in /etc/openvpn/easy-rsa/*;do [[ $i = *".cnf" || $i = *"/vars" ]] || chmod a+x $i;done
aws s3 cp s3://vpn-certs-and-files/WHICHVPN/user_passwd.csv /etc/openvpn/user_passwd.csv || true
aws s3 cp s3://vpn-certs-and-files/WHICHVPN/server.pem /root/server.pem || true
aws s3 cp s3://vpn-certs-and-files/WHICHVPN/ipp.txt /etc/openvpn/ipp.txt || true
aws s3 cp s3://vpn-certs-and-files/WHICHVPN/cert.key /root/cert.key || true
aws s3 cp s3://vpn-certs-and-files/WHICHVPN/cert.key /root/cert.pem || true
aws s3 cp s3://vpn-certs-and-files/csoc-vpn-nlb/ /root --recursive  --exclude "*"   --include "*.csv" --exclude "user_passwd.csv" || true
