#!/bin/bash
if [ -d /etc/openvpn/easy-rsa/ ]
then
	aws s3 sync /etc/openvpn/easy-rsa/ s3://vpn-certs-and-files/WHICHVPN/easy-rsa/
else
	echo directory /etc/openvpn/easy-rsa/ does not exist
fi

for F in /etc/openvpn/user_passwd.csv /etc/lighttpd/certs/server.pem /etc/openvpn/ipp.txt
do
	if [ -e $F ]
	then
		aws s3 cp $F s3://vpn-certs-and-files/WHICHVPN/
	else
		echo file $F does not exist
	fi
done
