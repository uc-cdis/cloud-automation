#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# Save the new and old cluster names to vars
environment=`gen3 api environment`
existing_cluster_name="$environment-gen3-metadata"
new_cluster_name="$environment-gen3-metadata-2"

# Gather existing cluster information
cluster_info=$(aws es describe-elasticsearch-domain --domain-name "$existing_cluster_name")

# Extract relevant information from the existing cluster
instance_type=`echo "$cluster_info" | jq -r '.DomainStatus.ElasticsearchClusterConfig.InstanceType'`
instance_count=`echo "$cluster_info" | jq -r '.DomainStatus.ElasticsearchClusterConfig.InstanceCount'`
volume_type=`echo "$cluster_info" | jq -r '.DomainStatus.EBSOptions.VolumeType'`
volume_size=`echo "$cluster_info" | jq -r '.DomainStatus.EBSOptions.VolumeSize'`
vpc_name=`echo "$cluster_info" | jq -r '.DomainStatus.VPCOptions.VPCId'`
subnet_ids=`echo "$cluster_info" | jq -r '.DomainStatus.VPCOptions.SubnetIds[]'`
security_groups=`echo "$cluster_info" | jq -r '.DomainStatus.VPCOptions.SecurityGroupIds[]'`
access_policies=`echo "$cluster_info" | jq -r '.DomainStatus.AccessPolicies'`
kms_key_id=`echo "$cluster_info" | jq -r '.DomainStatus.EncryptionAtRestOptions.KmsKeyId'`

# Check if the new Elasticsearch cluster name already exists
new_cluster=`aws es describe-elasticsearch-domain --domain-name "$new_cluster_name"`

if [ -n "$new_cluster" ]; then
    echo "Cluster $new_cluster_name already exists"
else
    echo "Cluster does not exist- creating..."
    # Create the new Elasticsearch cluster
    aws es create-elasticsearch-domain \
    --domain-name "$new_cluster_name" \
    --elasticsearch-version "7.10" \
    --elasticsearch-cluster-config \
        "InstanceType=$instance_type,InstanceCount=$instance_count" \
    --ebs-options \
        "EBSEnabled=true,VolumeType=$volume_type,VolumeSize=$volume_size" \
    --vpc-options "SubnetIds=${subnet_ids[*]},SecurityGroupIds=${security_groups[*]}" \
    --access-policies "$access_policies" \
    --encryption-at-rest-options "Enabled=true,KmsKeyId=$kms_key_id"\
    --node-to-node-encryption-options "Enabled=true"
    > /dev/null 2>&1

    # Wait for the new cluster to be available
    sleep_duration=60
    max_retries=10
    retry_count=0

    while [ $retry_count -lt $max_retries ]; do
    cluster_status=$(aws es describe-elasticsearch-domain --domain-name "$new_cluster_name" | jq -r '.DomainStatus.Processing')
    if [ "$cluster_status" != "true" ]; then
        echo "New cluster is available."
        break
    fi
    sleep $sleep_duration
    ((retry_count++))
    done

    if [ $retry_count -eq $max_retries ]; then
    echo "New cluster creation may still be in progress. Please check the AWS Management Console for the status."
    fi
fi
