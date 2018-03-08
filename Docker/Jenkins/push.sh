#!/bin/bash

docker tag cdis-jenkins:1.0.0 quay.io/cdis/jenkins:1.0.0
docker push quay.io/cdis/jenkins:1.0.0
