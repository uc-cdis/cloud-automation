The data-ingestion-job is specific to DataSTAGE.

To prep: 
Fill out the config file with creds here: `$(gen3_secrets_folder)/g3auto/data-ingestion-job/data_ingestion_job_config.json`
Place a newline-separated list of phs IDs here: `$(gen3_secrets_folder)/g3auto/data-ingestion-job/phsids.txt`
Optionally place a "data_requiring_manual_review.tsv" file here: `$(gen3_secrets_folder)/g3auto/data-ingestion-job/data_requiring_manual_review.tsv`
Optionally place a "genome_file_manifest" here: `$(gen3_secrets_folder)/g3auto/data-ingestion-job/genome_file_manifest.csv`

Usage:
`gen3 kube-setup-data-ingestion-job CREATE_GOOGLE_GROUPS <bool> CREATE_GENOME_MANIFEST <bool>`

If CREATE_GENOME_MANIFEST is true, the genome file manifest is required to live in `g3auto/data-ingestion-job/`.

The Dockerfile executable that this job runs can be found in this repository: https://github.com/uc-cdis/dataSTAGE-data-ingestion

If the executable is run successfully, a new pull request will be created with the job outputs in this repository: https://github.com/uc-cdis/dataSTAGE-data-ingestion-private