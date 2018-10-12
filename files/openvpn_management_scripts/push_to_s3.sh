#!/bin/bash
if [ -d /etc/openvpn/easy-rsa/ ]
then
	aws s3 sync /etc/openvpn/easy-rsa/ s3://WHICHVPN/easy-rsa/
else
	echo directory /etc/openvpn/easy-rsa/ does not exist
fi

for F in /etc/openvpn/user_passwd.csv /root/*.pem /root/*.key  /etc/openvpn/ipp.txt /root/*.csv
do
	if [ -e $F ]
	then
		aws s3 cp $F s3://WHICHVPN/
	else
		echo file $F does not exist
	fi
done
