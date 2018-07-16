#!/bin/bash
# entrypoint script for peregrine to update CA certificates before running

update-ca-certificates 

bash /peregrine/dockerrun.bash