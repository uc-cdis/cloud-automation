#/bin/bash

if [[ -z $(cat /etc/ca-certificates.conf | grep '!mozilla/DST_Root_CA_X3.crt') ]] && [[ ! -z $(cat /etc/ca-certificates.conf | grep 'mozilla/DST_Root_CA_X3.crt') ]]; then
  echo /etc/ca-certificates.conf | xargs sed -i 's/mozilla\/DST_Root_CA_X3.crt/!mozilla\/DST_Root_CA_X3.crt/g'
  update-ca-certificates
fi
