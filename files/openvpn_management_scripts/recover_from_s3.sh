#!/bin/bash
aws s3 sync s3://vpn-certs-and-files/WHICHVPN/easy-rsa/ /etc/openvpn/easy-rsa/
aws s3 cp s3://vpn-certs-and-files/WHICHVPN/user_passwd.csv /etc/openvpn/user_passwd.csv
aws s3 cp s3://vpn-certs-and-files/WHICHVPN/server.pem /etc/lighttpd/certs/server.pem
