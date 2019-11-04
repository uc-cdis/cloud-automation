The data-ingestion-job is specific to DataSTAGE.

Usage:
`gen3 kube-setup-data-ingestion-job [<phs_id_list_filepath>] [<data_requiring_manual_review_filepath>] [<genome_file_manifest_path>]
CREATE_GOOGLE_GROUPS <bool>`

These arguments are optional with default filepaths, and only the phs id file needs to actually exist.
It is by default expected to live here:
`g3auto/data-ingestion-job/phsids.txt`

This job also requires a config file with creds to be filled out in advance, here:
`g3auto/data-ingestion-job/data_ingestion_job_config.json`

The Dockerfile executable that this job runs can be found in this repository: https://github.com/uc-cdis/dataSTAGE-data-ingestion

If the executable is run successfully, a new pull request will be created with the job outputs in this repository: https://github.com/uc-cdis/dataSTAGE-data-ingestion-private