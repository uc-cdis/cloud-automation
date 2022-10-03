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


# cron job to distribute licenses if using Stata workspaces
if [ "$(g3kubectl get configmaps/manifest-hatchery -o yaml | grep "\"image\": .*stata.*")" ];
then
    gen3 job cron distribute-licenses '* * * * *'
fi

policy=$( cat <<EOM
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Resource": "arn:aws:iam::*:role/csoc_adminvm*"
        },
        {
            "Effect": "Allow",
            "Action": "ec2:*",
            "Resource": "*"
        },
        {
            "Sid": "DynamoDB",
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
        }
    ]
}
EOM
)
saName=$(echo "hatchery-service-account" | head -c63)
echo $saName
if ! g3kubectl get sa "$saName" -o json | jq -e '.metadata.annotations | ."eks.amazonaws.com/role-arn"' > /dev/null 2>&1; then
    roleName="$(gen3 api safe-name hatchery-sa)"
    gen3 awsrole create $roleName $saName
    policyName="$(gen3 api safe-name hatchery-policy)"
    policyInfo=$(gen3_aws_run aws iam create-policy --policy-name "$policyName" --policy-document "$policy" --description "Allow hathcery to assume csoc_adminvm role in other accounts, for multi-account workspaces")
    if [ -n "$policyInfo" ]; then
    policyArn="$(jq -e -r '.["Policy"].Arn' <<< "$policyInfo")" || { echo "Cannot get 'Policy.Arn' from output: $policyInfo"; return 1; }
    else
        echo "Unable to create policy $policyName. Assuming it already exists and continuing"
        policyArn=$(gen3_aws_run aws iam list-policies --query "Policies[?PolicyName=='$policyName'].Arn" --output text)
    fi

    gen3_log_info "Attaching policy '${policyName}' to role '${roleName}'"
    gen3 awsrole attach-policy ${policyArn} --role-name ${roleName} --force-aws-cli || exit 1
    gen3 awsrole attach-policy "arn:aws:iam::aws:policy/AWSResourceAccessManagerFullAccess" --role-name ${roleName} --force-aws-cli || exit 1
fi


g3kubectl apply -f "${GEN3_HOME}/kube/services/hatchery/hatchery-service.yaml"
gen3 roll hatchery
gen3 job cron hatchery-reaper '@daily'