#!/bin/bash

for users in $(cut -d: -f1 /etc/passwd); do
  for directory in $(find /home/$users/.local/share/gen3 -name .terraform); do
    echo "Removing $directory/plugins" >> /terraformScriptLogs-$(date -u +%Y%m%d))
    rm -rf $directory/plugins
  done
done
