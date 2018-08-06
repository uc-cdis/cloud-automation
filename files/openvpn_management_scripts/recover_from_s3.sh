#!/bin/bash
aws s3 sync --exclude "csoc-vpn-bucket*" --exclude "user_passwd.csv" s3://vpn-certs-and-files/ /etc/openvpn/easy-rsa/keys/
