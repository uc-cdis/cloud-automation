The data-ingestion-job is specific to DataSTAGE.

Usage:
`gen3 kube-setup-data-ingestion-job 
	[-phs_id_list_filepath <phs_id_list_filepath>] 
	[-data_requiring_manual_review_filepath <data_requiring_manual_review_filepath>] 
	[-create_google_groups <bool>]`

Both of these arguments are optional with default filepaths, and only the first file needs to actually exist. 
The first file is by default expected to live here:
`g3auto/data-ingestion-job/data-ingestion-job-phs-id-list.txt`

This job also requires a config file with creds to be filled out in advance, here:
`g3auto/data-ingestion-job/data_ingestion_job_config.json`

The Dockerfile executable that this job runs can be found in this repository: https://github.com/uc-cdis/dataSTAGE-data-ingestion

If the executable is run successfully, a new pull request will be created with the job outputs in this repository: https://github.com/uc-cdis/dataSTAGE-data-ingestion-private