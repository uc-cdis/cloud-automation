# TL;DR

gen3 integration with GCP

## Gen3 and GCP

Currently CTDS deploys Gen3 services for a commons to an EKS kubernetes cluster running on AWS.  The commons interacts with GCP storage buckets via service accounts.

## csoc-adminvm service account

Create a `csoc-adminvm` service account for each project that you want to interact with from the adminvm via `gcloud`, `gsutil`, or `terraform`.  Give the service account the roles for administrative privileges on all the GCP services that the commons might rely on:
* Storage Admin
* Project IAM Admin
* Google Cloud Managed Identity Admin
* Service Account Key Admin

Create a key for the service account, then upload it to the admin vm, and save it under `Gen3Secrets/gcp/`.  Finally, log the new secret in the local git repo:

```
cd "$(gen3_secrets_folder)"
git add gcp
git commit -m 'new gcp csoc-adminvm service account'
```

## Admin VM Setup

We dedicate a Linux user on an admin VM to the administration of each commons.  The GCP SDK allows for a user to switch between multiple configurations for different GCP projects and credentials.

First, create and activate a new SDK configuration.  This is the `profile` name that will be used with the `gen3` terraform tools like `gen3 workon`.  

```
gcloud config configurations create config-name
```

Next, link the service account and project with the new configuration.  The `gen3` terraform tools assume that the service account
key for a particular configuration is available at `Gen3Secrets/gcp/config-name.json`.

```
gcloud config configurations activate config-name
gcloud auth activate-service-account --key-file=$(gen3_secrets_folder)/gcp/config-name.json
gcloud config set core/project "$(jq -r .project_id < $(gen3_secrets_folder)/gcp/config-name.json)"
```

Finally, verify that everything works:
```
gsutil ls
```

## Key Rotation

See the documentation for the [gen3 secrets gcp](./secrets.md) command line tools.

## Other

### SA roles

```
gcloud projects get-iam-policy dcf-integration  --flatten="bindings[].members" --format='table(bindings.role)' --filter="bindings.members:csoc-adminvm@dcf-integration.iam.gserviceaccount.com"
```
