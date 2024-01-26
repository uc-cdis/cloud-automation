# Gen3 Discovery AI Configuration

Expects data in a `gen3-discovery-ai` folder relative to 
where the `manifest.json` is. 

Basic setup:

`{{dir where manifest.json is}}/gen3-discovery-ai/knowledge/`

- `tsvs` folder
    - tsvs with topic_name at beginning of file
- `markdown` folder
    - {{topic_name_1}}
        - markdown file(s)
    - {{topic_name_2}}
        - markdown file(s)

The `kube-setup-gen3-discovery-ai` script syncs the above `/knowledge` folder to
an S3 bucket. The service configuration then pulls from the S3 bucket and runs load commands 
to get the data into chromadb.

> Note: See the `gen3-discovery-ai` service repo docs and README for more details on data load capabilities.

Check the `gen3-discovery-ai-deploy.yaml` for what commands are being run in the automation.

Expects secrets setup in `g3auto/gen3-discovery-ai` folder
 - `credentials.json`: Google service account key if using a topic with Google Vertex AI
 - `env`: .env file contents for service configuration (see service repo for a default one)

## Populating Disk for In-Memory Vectordb Chromadb

In order to setup pre-configured topics, we need to load a bunch of data 
into Chromadb (which is an in-mem vectordb with an option to persist to disk).

To load topics consistently, we setup an S3 bucket to house the persisted 
data for the vectordb.

### Getting data from S3 in mem

We specify a path for Chromadb to use for persisted data and when it sees 
data there, it loads it in. So the deployment automation: 1. aws syncs the bucket
and then 2. calls a script to load the files into the in-mem vectorstore from there. 
