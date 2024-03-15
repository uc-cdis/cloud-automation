#!/bin/bash
#
# The optional jupyterhub setup for workspaces

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# Jenkins friendly
export WORKSPACE="${WORKSPACE:-$HOME}"

namespace="$(gen3 db namespace)"
notebookNamespace="$(gen3 jupyter j-namespace)"

gen3 jupyter j-namespace setup
[[ -z "$GEN3_ROLL_ALL" ]] && gen3 gitops configmaps

#
# this may fail in gitops-sync if the cron job
# does not have permissions at the cluster level
#
(g3k_kv_filter ${GEN3_HOME}/kube/services/hatchery/serviceaccount.yaml BINDING_ONE "name: hatchery-binding1-$namespace" BINDING_TWO "name: hatchery-binding2-$namespace" CURRENT_NAMESPACE "namespace: $namespace" | g3kubectl apply -f -) || true

function exists_or_create_gen3_license_table() {
    # Create dynamodb table for gen3-license if it does not exist.
    TARGET_TABLE="$1"
    echo "Checking for dynamoDB table: ${TARGET_TABLE}"

    FOUND_TABLE=`aws dynamodb list-tables | jq -r .TableNames | jq -c -r '.[]' | grep $TARGET_TABLE`
    if [ -n "$FOUND_TABLE" ]; then
        echo "Target table already exists in dynamoDB: $FOUND_TABLE"
    else
        echo "Creating table ${TARGET_TABLE}"
        GSI=`g3kubectl get configmaps/manifest-hatchery -o json | jq -r '.data."license-user-maps-global-secondary-index"'`
        if [[ -z "$GSI" || "$GSI" == "null" ]]; then
            echo "Error: No global-secondary-index in configuration"
            return 0
        fi
        aws dynamodb create-table \
            --no-cli-pager \
            --table-name "$TARGET_TABLE" \
            --attribute-definitions AttributeName=itemId,AttributeType=S \
                AttributeName=environment,AttributeType=S \
                AttributeName=isActive,AttributeType=S \
            --key-schema AttributeName=itemId,KeyType=HASH \
                AttributeName=environment,KeyType=RANGE \
            --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
            --global-secondary-indexes \
                "[
                    {
                        \"IndexName\": \"$GSI\",
                        \"KeySchema\": [{\"AttributeName\":\"environment\",\"KeyType\":\"HASH\"},
                            {\"AttributeName\":\"isActive\",\"KeyType\":\"RANGE\"}],
                        \"Projection\":{
                            \"ProjectionType\":\"INCLUDE\",
                            \"NonKeyAttributes\":[\"itemId\",\"userId\",\"licenseId\",\"licenseType\"]
                        },
                        \"ProvisionedThroughput\": {
                            \"ReadCapacityUnits\": 5,
                            \"WriteCapacityUnits\": 3
                        }
                    }
                ]"
    fi
}

TARGET_TABLE=`g3kubectl get configmaps/manifest-hatchery -o json | jq -r '.data."license-user-maps-dynamodb-table"'`
if [[ -z "$TARGET_TABLE" || "$TARGET_TABLE" == "null" ]]; then
    echo "No gen3-license table in configuration"
    # cron job to distribute licenses if using Stata workspaces but not using dynamoDB
    if [ "$(g3kubectl get configmaps/manifest-hatchery -o yaml | grep "\"image\": .*stata.*")" ];
    then
        gen3 job cron distribute-licenses '* * * * *'
    fi
else
    echo "Found gen3-license table in configuration: $TARGET_TABLE"
    exists_or_create_gen3_license_table "$TARGET_TABLE"
fi

# if `nextflow-global.imagebuilder-reader-role-arn` is set in hatchery config, allow hatchery
# to assume the configured role
imagebuilderRoleArn=$(g3kubectl get configmap manifest-hatchery -o jsonpath={.data.nextflow-global} | jq -r '."imagebuilder-reader-role-arn"')
assumeImageBuilderRolePolicyBlock=""
if [ -z "$imagebuilderRoleArn" ]; then
    gen3_log_info "No 'nexftlow-global.imagebuilder-reader-role-arn' in Hatchery configuration, not granting AssumeRole"
else
    gen3_log_info "Found 'nexftlow-global.imagebuilder-reader-role-arn' in Hatchery configuration, granting AssumeRole"
    assumeImageBuilderRolePolicyBlock=$( cat <<EOM
        {
            "Sid": "AssumeImageBuilderReaderRole",
            "Effect": "Allow",
            "Action": [
                "sts:AssumeRole"
            ],
            "Resource": "$imagebuilderRoleArn"
        },
EOM
)
fi

policy=$( cat <<EOM
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AssumeCsocAdminRole",
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Resource": "arn:aws:iam::*:role/csoc_adminvm*"
        },
$assumeImageBuilderRolePolicyBlock
        {
            "Effect": "Allow",
            "Action": "ec2:*",
            "Resource": "*"
        },
        {
            "Sid": "ManageDynamoDB",
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchGet*",
                "dynamodb:DescribeStream",
                "dynamodb:DescribeTable",
                "dynamodb:Get*",
                "dynamodb:Query",
                "dynamodb:Scan",
                "dynamodb:BatchWrite*",
                "dynamodb:CreateTable",
                "dynamodb:Delete*",
                "dynamodb:Update*",
                "dynamodb:PutItem"
            ],
            "Resource": "arn:aws:dynamodb:*:*:table/*"
        },
        {
            "Sid": "CreateNextflowBatchWorkspaces",
            "Effect": "Allow",
            "Action": [
                "batch:DescribeComputeEnvironments",
                "batch:CreateComputeEnvironment",
                "batch:CreateJobQueue",
                "batch:TagResource",
                "iam:ListPolicies",
                "iam:CreatePolicy",
                "iam:TagPolicy",
                "iam:ListPolicyVersions",
                "iam:CreatePolicyVersion",
                "iam:DeletePolicyVersion",
                "iam:ListRoles",
                "iam:CreateRole",
                "iam:TagRole",
                "iam:AttachRolePolicy",
                "iam:CreateUser",
                "iam:TagUser",
                "iam:AttachUserPolicy",
                "iam:ListAccessKeys",
                "iam:CreateAccessKey",
                "iam:DeleteAccessKey",
                "iam:GetInstanceProfile",
                "iam:CreateInstanceProfile",
                "iam:AddRoleToInstanceProfile",
                "iam:PassRole",
                "s3:CreateBucket"
            ],
            "Resource": "*"
        },
        {
            "Sid": "PassRoleForNextflowBatchWorkspaces",
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": [
                "arn:aws:iam::*:role/*ecsInstanceRole"
            ]
        }
    ]
}
EOM
)

saName=$(echo "hatchery-service-account" | head -c63)
echo Service account name: $saName
echo Policy document: $policy

# if the policy has changed and must be updated, run:
# `kubectl delete sa hatchery-service-account && gen3 kube-setup-hatchery`
if ! g3kubectl get sa "$saName" -o json | jq -e '.metadata.annotations | ."eks.amazonaws.com/role-arn"' > /dev/null 2>&1; then
    roleName="$(gen3 api safe-name hatchery-sa)"
    gen3 awsrole create $roleName $saName
    policyName="$(gen3 api safe-name hatchery-policy)"
    policyInfo=$(gen3_aws_run aws iam create-policy --policy-name "$policyName" --policy-document "$policy" --description "Allow hatchery to assume csoc_adminvm role in other accounts and manage dynamodb for multi-account workspaces, and to create resources for nextflow workspaces")
    if [ -n "$policyInfo" ]; then
        policyArn="$(jq -e -r '.["Policy"].Arn' <<< "$policyInfo")" || { echo "Cannot get 'Policy.Arn' from output: $policyInfo"; return 1; }
    else
        echo "Unable to create policy '$policyName'. Assume it already exists and create a new version to update the permissions..."
        policyArn=$(gen3_aws_run aws iam list-policies --query "Policies[?PolicyName=='$policyName'].Arn" --output text)

        # there can only be up to 5 versions, so delete old versions (except the current default one)
        versions="$(gen3_aws_run aws iam list-policy-versions --policy-arn $policyArn | jq -r '.Versions[] | select(.IsDefaultVersion != true) | .VersionId')"
        versions=(${versions}) # string to array
        for v in "${versions[@]}"; do
            echo "Deleting old version '$v'"
            gen3_aws_run aws iam delete-policy-version --policy-arn $policyArn --version-id $v
        done

        # create the new version
        gen3_aws_run aws iam create-policy-version --policy-arn "$policyArn" --policy-document "$policy" --set-as-default
    fi
    gen3_log_info "Attaching policy '${policyName}' to role '${roleName}'"
    gen3 awsrole attach-policy ${policyArn} --role-name ${roleName} --force-aws-cli || exit 1
    gen3 awsrole attach-policy "arn:aws:iam::aws:policy/AWSResourceAccessManagerFullAccess" --role-name ${roleName} --force-aws-cli || exit 1
fi

if [[ -f "$(gen3_secrets_folder)/prisma/apikey.json" ]]; then
    ACCESSKEYID=$(jq -r .AccessKeyID "$(gen3_secrets_folder)/prisma/apikey.json")
    SECRETKEY=$(jq -r .SecretKey "$(gen3_secrets_folder)/prisma/apikey.json")
    if [[ ! -z "$ACCESSKEYID" && ! -z "$SECRETKEY" ]]; then
        gen3_log_info "Found prisma apikey, creating kubernetes secret so hatchery can do prismacloud stuff.."
        g3kubectl delete secret prisma-secret --ignore-not-found
        g3kubectl create secret generic prisma-secret --from-literal=AccessKeyId=$ACCESSKEYID --from-literal=SecretKey=$SECRETKEY
    fi
fi

g3kubectl apply -f "${GEN3_HOME}/kube/services/hatchery/hatchery-service.yaml"
gen3 roll hatchery
gen3 job cron hatchery-reaper "*/5 * * * *"
