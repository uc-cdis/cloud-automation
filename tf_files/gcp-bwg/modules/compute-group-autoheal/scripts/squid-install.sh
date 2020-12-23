#! /bin/bash
echo "***** Checking for Squid install.*****"
if apt-cache policy squid | grep -q 'Installed: (none)'; then
        echo "*****Installing Squid******"
        sudo apt-get update
        sudo apt-get install -y squid
        gcloud config set account "$LOGGING_SA"
        gcloud logging write squid-log "Squid was installed" --severity=NOTICE
else
        echo "Squid alredy installed"
        gcloud config set account "$LOGGING_SA"
        gcloud logging write squid-log "Squid install script rerun" --severity=INFO
fi