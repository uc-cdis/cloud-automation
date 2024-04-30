"""
See documentation at https://github.com/uc-cdis/cloud-automation/blob/master/files/scripts/ecr-access-job.md
"""

from decimal import Decimal
import json
import os
from typing import List
import uuid

import boto3
from boto3.dynamodb.conditions import Attr


REGION = "us-east-1"

# for local testing. in production, use a service account instead of a key.
MAIN_ACCOUNT_CREDS = {"key_id": os.environ.get("KEY_ID"), "key_secret": os.environ.get("KEY_SECRET")}


def escapism(string: str) -> str:
    """
    This is a direct translation of Hatchery's `escapism` golang function to python.
    We need to escape the username in the same way it's escaped by Hatchery's `escapism` function because
    special chars cannot be used in an ECR repo name, and so that the ECR repo generated here matches the
    name expected by Hatchery.
    """
    safeBytes = "abcdefghijklmnopqrstuvwxyz0123456789"
    escaped = ""
    for v in string:
        if v not in safeBytes:
            hexCode = "{0:02x}".format(ord(v))
            escaped += "-" + hexCode
        else:
            escaped += v
    return escaped


def get_configs() -> (str, str):
    table_name = os.environ.get("PAY_MODELS_DYNAMODB_TABLE")
    if not table_name:
        raise Exception("Missing 'PAY_MODELS_DYNAMODB_TABLE' environment variable")

    ecr_role_arn = os.environ.get("ECR_ACCESS_JOB_ARN")
    if not ecr_role_arn:
        raise Exception("Missing 'ECR_ACCESS_JOB_ARN' environment variable")

    return table_name, ecr_role_arn


def query_usernames_and_account_ids(table_name: str) -> List[dict]:
    """
    Returns:
        List[dict]: [ { "user_id": "user1@username.com", "account_id": "123456" } ]
    """
    if MAIN_ACCOUNT_CREDS["key_id"]:
        session = boto3.Session(
            aws_access_key_id=MAIN_ACCOUNT_CREDS["key_id"],
            aws_secret_access_key=MAIN_ACCOUNT_CREDS["key_secret"],
        )
    else:
        session = boto3.Session()
    dynamodb = session.resource("dynamodb", region_name=REGION)
    table = dynamodb.Table(table_name)

    # get usernames and AWS account IDs from DynamoDB
    queried_keys = ["user_id", "account_id"]
    filter_expr = Attr("workspace_type").eq("Direct Pay")
    proj = ", ".join("#" + key for key in queried_keys)
    expr = {"#" + key: key for key in queried_keys}
    response = table.scan(
        FilterExpression=filter_expr,
        ProjectionExpression=proj,
        ExpressionAttributeNames=expr,
    )
    assert response.get("ResponseMetadata", {}).get("HTTPStatusCode") == 200, response
    items = response["Items"]
    # if the response is paginated, get the rest of the items
    while response["Count"] > 0:
        if "LastEvaluatedKey" not in response:
            break
        response = table.scan(
            FilterExpression=filter_expr,
            ProjectionExpression=proj,
            ExpressionAttributeNames=expr,
            ExclusiveStartKey=response["LastEvaluatedKey"],
        )
        assert (
            response.get("ResponseMetadata", {}).get("HTTPStatusCode") == 200
        ), response
        items.extend(response["Items"])

    return items


def update_access_in_ecr(repo_to_account_ids: List[dict], ecr_role_arn: str) -> None:
    # get access to ECR in the account that contains the ECR repos
    if MAIN_ACCOUNT_CREDS["key_id"]:
        sts = boto3.client(
            "sts",
            aws_access_key_id=MAIN_ACCOUNT_CREDS["key_id"],
            aws_secret_access_key=MAIN_ACCOUNT_CREDS["key_secret"],
        )
    else:
        sts = boto3.client("sts")
    assumed_role = sts.assume_role(
        RoleArn=ecr_role_arn,
        DurationSeconds=900,  # minimum time for aws assume role as per boto docs
        RoleSessionName=f"ecr-access-assume-role-{str(uuid.uuid4())[:8]}",
    )
    assert "Credentials" in assumed_role, "Unable to assume role"
    ecr = boto3.client(
        "ecr",
        aws_access_key_id=assumed_role["Credentials"]["AccessKeyId"],
        aws_secret_access_key=assumed_role["Credentials"]["SecretAccessKey"],
        aws_session_token=assumed_role["Credentials"]["SessionToken"],
    )

    # for each ECR repo, whitelist the account IDs so users can access the repo
    for repo, account_ids in repo_to_account_ids.items():
        print(f"Allowing AWS accounts {account_ids} to use ECR repository '{repo}'")
        policy = {
            "Version": "2008-10-17",
            "Statement": [
                {
                    "Sid": "AllowCrossAccountPull",
                    "Effect": "Allow",
                    "Principal": {
                        "AWS": [
                            f"arn:aws:iam::{account_id}:root"
                            for account_id in account_ids
                        ]
                    },
                    "Action": [
                        "ecr:BatchCheckLayerAvailability",
                        "ecr:BatchGetImage",
                        "ecr:GetAuthorizationToken",
                        "ecr:GetDownloadUrlForLayer",
                    ],
                }
            ],
        }
        # Note that this is overwriting the repo policy, not appending to it. This means we can't have 2 dynamodb
        # tables pointing at the same set of ECR repos: the repos would only allow the accounts in the table for
        # which the script was run most recently. eg QA and Staging can't use the same ECR repos.
        # Appending is not possible since this code will eventually rely on Arborist for authorization information
        # and we'll need to overwrite in order to remove expired access.
        try:
            ecr.set_repository_policy(
                repositoryName=repo,
                policyText=json.dumps(policy),
            )
        except Exception as e:
            print(f"  Unable to update '{repo}'; skipping it: {e}")


def main() -> None:
    table_name, ecr_role_arn = get_configs()
    items = query_usernames_and_account_ids(table_name)

    # construct mapping: { ECR repo url: [ AWS account IDs with access ] }
    ecr_repo_prefix = "nextflow-approved"
    repo_to_account_ids = {
        f"{ecr_repo_prefix}/{escapism(e['user_id'])}": [e["account_id"]]
        for e in items
        if "account_id" in e
    }
    print(
        "Mapping of ECR repository to allowed AWS accounts:\n",
        json.dumps(repo_to_account_ids, indent=2),
    )

    update_access_in_ecr(repo_to_account_ids, ecr_role_arn)


if __name__ == "__main__":
    main()
