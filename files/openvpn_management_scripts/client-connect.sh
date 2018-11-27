#!/bin/bash

if [ -e /etc/openvpn/bin/settings.sh ] && [ -z "$VPN_SETTINGS_LOADED" ]
then
    source /etc/openvpn/bin/settings.sh
fi

set -e
set -u

custom_user_config="${1}"

# first, strip underscores
cleaned_username=${username//_/}
# next, replace spaces with underscores
cleaned_username=${cleaned_username// /_}
# now, clean out anything that's not alphanumeric or an underscore
cleaned_username=${cleaned_username//[^a-zA-Z0-9_]/}
# finally, lowercase with TR
cleaned_username=`echo -n $cleaned_username | tr A-Z a-z`

#Ephermeral config file template to append to user's push
custom_config_file="${OPENVPN_CONF_DIR}/environments/${cleaned_username}"

#optional user whitelist
## Assumes everyone gets all access, but some users are limited in scope
## FIXME:  What special characters are allowed in COMMON_NAME by OpenVPN currently in 2.4?
user_environment_whitelist="${OPENVPN_CONF_DIR}/client-restrictions/${common_name}"

# Check is whitelist for "environment" requested
if [ -e "$user_environment_whitelist" ]
then
    grep -E "^$cleaned_username$" "$user_environment_whitelist" || exit 1
fi

if [ -e $custom_config_file ]
then
    cat ${custom_config_file} >> $custom_user_config
fi

exit 0
