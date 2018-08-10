#!/bin/bash
aws s3 sync s3://vpn-certs-and-files/WHICHVPN/easy-rsa/ /etc/openvpn/easy-rsa/ || true
aws s3 cp s3://vpn-certs-and-files/WHICHVPN/user_passwd.csv /etc/openvpn/user_passwd.csv || true
aws s3 cp s3://vpn-certs-and-files/WHICHVPN/server.pem /root/server.pem || true
aws s3 cp s3://vpn-certs-and-files/WHICHVPN/ipp.txt /etc/openvpn/ipp.txt || true
