#!/bin/bash
# entrypoint script for data-portal to healthcheck sheepdog and peregrine to 
# make sure they are ready before dataportal attempts to get information from 
# them

sleep 10

until curl -f -s -o /dev/null http://nginx/api/v0/submission/getschema ; do
    echo "peregrine not ready, waiting..."
    sleep 10
done

until curl -f -s -o /dev/null http://nginx/api/v0/submission/_dictionary/_all; do
    echo "sheepdog not ready, waiting..."
    sleep 10
done

echo "both services are ready"
bash ./dockerStart.sh