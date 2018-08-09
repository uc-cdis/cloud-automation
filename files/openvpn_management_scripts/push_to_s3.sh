#!/bin/bash
aws s3 sync /etc/openvpn/easy-rsa/keys/ s3://vpn-certs-and-files/WHICHVPN/keys/
aws s3 cp /etc/openvpn/user_passwd.csv s3://vpn-certs-and-files/WHICHVPN/
aws s3 cp /etc/lighttpd/certs/server.pem s3://vpn-certs-and-files/WHICHVPN/
