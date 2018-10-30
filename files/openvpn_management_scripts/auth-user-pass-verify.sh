#!/bin/bash
#   Copyright 2017 CDIS
#   Author: Ray Powell rpowell1@uchicago.edu
#  This script assumes that openvpn is santizing inputs like it should. Converting to underscores.
#  It checks the passwd hash table to ensure user supplied password is correct

if [ -e /etc/openvpn/bin/settings.sh ] && [ -z "$VPN_SETTINGS_LOADED" ]
then
    source /etc/openvpn/bin/settings.sh
fi
# first, strip underscores
CLEAN=${common_name//_/}
# next, replace spaces with underscores
CLEAN=${CLEAN// /_}
# now, clean out anything that's not alphanumeric or an underscore
CLEAN=${CLEAN//[^a-zA-Z0-9_]/}
# finally, lowercase with TR
CLEAN=`echo -n $CLEAN | tr A-Z a-z`
export username="${CLEAN}"

$VPN_BIN_ROOT/auth-user-pass-verify.py
