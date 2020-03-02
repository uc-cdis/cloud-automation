The data-ingestion-job is specific to DataSTAGE.

To prep:
Specify an image for the pipeline in the versions block of your manifest, for example:
`"data-ingestion-pipeline": "quay.io/cdis/datastage-data-ingestion"`
Fill out the config file with creds here: `$(gen3_secrets_folder)/g3auto/data-ingestion-job/data_ingestion_job_config.json`
Place a newline-separated list of phs IDs here: `$(gen3_secrets_folder)/g3auto/data-ingestion-job/phsids.txt`
Optionally place a "data_requiring_manual_review.tsv" file here: `$(gen3_secrets_folder)/g3auto/data-ingestion-job/data_requiring_manual_review.tsv`
Optionally place a "genome_file_manifest" here: `$(gen3_secrets_folder)/g3auto/data-ingestion-job/genome_file_manifest.csv`

Usage:
`gen3 kube-setup-data-ingestion-job CREATE_GOOGLE_GROUPS <bool> CREATE_GENOME_MANIFEST <bool>`

If CREATE_GENOME_MANIFEST is false, the genome file manifest is required to live in `g3auto/data-ingestion-job/`.

The Dockerfile executable that this job runs can be found in this repository: https://github.com/uc-cdis/dataSTAGE-data-ingestion

If the executable is run successfully, a new pull request will be created with the job outputs in this repository: https://github.com/uc-cdis/dataSTAGE-data-ingestion-private

Config file example:

    {
    "gs_creds": {
        "type": "service_account",
        "project_id": "",
        "private_key_id": "",
        "private_key": "",
        "client_email": "",
        "client_id": "",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url": ""
    },
    "genome_bucket_aws_creds": {
        "aws_access_key_id": "",
        "aws_secret_access_key": ""
    },
    "local_data_aws_creds": {
        "bucket_name": "",
        "aws_access_key_id": "",
        "aws_secret_access_key": ""
    },
    "gcp_project_id": "",
    "github_user_email": "",
    "github_personal_access_token": "",
    "github_user_name": "",
    "git_org_to_pr_to": "uc-cdis",
    "git_repo_to_pr_to": "dataSTAGE-data-ingestion-private"
    }