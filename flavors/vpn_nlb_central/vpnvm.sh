#!/bin/bash
sudo -E su  <<  EOF
#Install postfix and mailutils
cd /root
sudo apt-get update
sudo debconf-set-selections <<< "postfix postfix/mailname string planx-pla.net"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
sudo apt-get install -y postfix
sudo apt-get install mailutils -y
# Install virtualenv
sudo apt-get install python-virtualenv -y

#Install uuidgen
sudo apt-get install uuid-runtime -y

#Install git
sudo apt-get install git -y


openssl req -x509 -nodes -days 365 -newkey rsa:2048 -subj '/C=US/ST=IL/L=Chicago/O=CDIS' -keyout /root/cert.key -out /root/cert.pem
cat /root/cert.key /root/cert.pem > /root/server.pem


# Providing all the required inputs for install_vpn.sh script

# git clone git@github.com:LabAdvComp/openvpn_management_scripts.git

#Make changes to the install_vpn.sh script

export FQDN="raryatestvpnv1.planx-pla.net"; export cloud="planxvpn1"; export SERVER_PEM="/root/server.pem"; bash /root/openvpn_management_scripts/install_ovpn.sh

#export FQDN="raryatestvpnv1.planx-pla.net"; export cloud="planxvpn"; export EMAIL="support@datacommons.io"; export SERVER_PEM="/root/server.pem"; export VPN_SUBNET="192.168.192.0/20"; export VM_SUBNET="10.128.0.0/20"; bash install_ovpn.sh

### need to install lighttpd

apt-get install -y lighttpd
cp /etc/openvpn/bin/templates/lighttpd.conf.template  /etc/lighttpd/lighttpd.conf
mkdir -p --mode=750 /var/www/qrcode
chown openvpn:www-data /var/www/qrcode
mkdir /etc/lighttpd/certs
cp /root/server.pem /etc/lighttpd/certs/server.pem
service lighttpd restart

# Make changes to the iptables

iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -s 10.128.0.0/20 -d 192.168.192.0/20 -i tun0 -o eth0 -m conntrack --ctstate NEW -j ACCEPT
iptables -t nat -A POSTROUTING -s  192.168.192.0/20 -d 0.0.0.0/0  -o eth0 -j MASQUERADE
echo 1 > /proc/sys/net/ipv4/ip_forward

 # Restart VPN
 openvpn --daemon ovpn-openvpn --status /run/openvpn/openvpn.status 10 --cd /etc/openvpn --script-security 2 --config /etc/openvpn/openvpn.conf --writepid /run/openvpn/openvpn.pid
systemctl restart openvpn


## Make sure the securoty groups on the VM allows TCP access for 80,443,1194

EOF


