#!/usr/bin/env bash
set -x
# Set env variable for profile
export AWS_PROFILE=BurwoodTest
aws_list=$(aws configure list)
echo "$aws_list"
dir="/tmp"
echo "${dir}"
date=$(date +"%m_%d_%Y %T")
aws_account="BurwoodTest"

inspec exec /home/ec2-user/inspec-uchi/uchi-inspec-policy -t aws:// --reporter cli json:"${dir}/uchi_${aws_account}_${date}.json" #>> /dev/null 2>&1 

aws s3 cp ${dir}/uchi_"${aws_account}_${date}.json" s3://burwood-cdistest/
 
echo "copied data to s3 bucket"
