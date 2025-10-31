# ecr-access-job

### How to run

Configure `global.ecr-access-job-role-arn` to the ARN of the `EcrRepoPolicyUpdateRole` role (described below) in the `manifest.json` file.

Run `gen3 kube-setup-ecr-access-cronjob` to set up the ECR access cronjob.

### What does it do?

The job runs the `ecr-access-job.py` script.

This script updates the configuration of ECR repositories so that users can access the repositories that were created for them.

It queries a DynamoDB table which has the following (simplified) structure:
| user_id            | workspace_type       | account_id |
| ------------------ | -------------------- | ---------- |
| user1@username.com | Direct Pay           | 123456     |
| user2@username.com | Direct Pay           | 789012     |
| user1@username.com | Other workspace type | <null>     |

and then allows each AWS account to acccess the appropriate ECR repositories. The users' ECR repositories are based on their username as stored in the table. For example, `user1@username.com`'s ECR repository is assumed to be `nextflow-approved/user1-40username-2ecom`.

### Access needed

- "EcrRepoPolicyUpdateRole" role in the account (Acct1) that contains the ECR repositories:

**Note:** `kube-setup-ecr-access-cronjob.sh` assumes this role already exists.

Permissions:
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "UpdateEcrRepoPolicy",
            "Effect": "Allow",
            "Action": "ecr:SetRepositoryPolicy",
            "Resource": "arn:aws:ecr:us-east-1:<Acct1 ID>:repository/nextflow-approved/*"
        }
    ]
}
```

Trust policy (allows Acct2):
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Sid": "AllowAssumingRole",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::<Acct2 ID>:root"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```

- Policy in the account (Acct2) that contains the DynamoDB table (created automatically by `kube-setup-ecr-access-cronjob.sh`):
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ReadDynamoDB",
            "Effect": "Allow",
            "Action": [
                "dynamodb:Scan"
            ],
            "Resource": "arn:aws:dynamodb:<region>:<Acct2 ID>:table/<table name>"
        },
        {
            "Sid": "AssumeEcrRole",
            "Effect": "Allow",
            "Action": [
                "sts:AssumeRole"
            ],
            "Resource": "arn:aws:iam::<Acct1 ID>:role/<role name>"
        }
    ]
}
```
