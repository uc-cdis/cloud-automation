To execute this container inside a kubernetes pod you have to set the variables for the profile of the environment you want to use

Environment variables that need to be set are

AWS_PROFILE
value {profile}
AWS_CONFIG_FILE
value {path to aws creds config}
AWS_SHARED_CREDENTIALS_FILE
value { path to aws reds credentials}

You need to create kubernetes secret and mount the secret and inject into cronjob pod
