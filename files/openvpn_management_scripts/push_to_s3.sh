#!/bin/bash
aws s3 sync /etc/openvpn/easy-rsa/ s3://vpn-certs-and-files/WHICHVPN/easy-rsa/
aws s3 cp /etc/openvpn/user_passwd.csv s3://vpn-certs-and-files/WHICHVPN/
aws s3 cp /root/certs/server.pem s3://vpn-certs-and-files/WHICHVPN/
aws s3 cp /etc/openvpn/ipp.txt s3://vpn-certs-and-files/WHICHVPN/
