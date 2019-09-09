#! /bin/bash
echo "***** Checking for OpenVPN install."
if apt-cache policy OpenVPN | grep -q 'Installed: (none)'; then
        echo "*****Installing OpenVPN******"
        sudo apt-get update
        sudo apt-get install -y openvpn
        gcloud logging write openvpn-log "OpenVPN Installed" --severity=NOTICE
else
        echo "OpenVPN alredy installed"
        gcloud logging write openvpn-log "OpenVPN install script rerun" --severity=INFO
fi
