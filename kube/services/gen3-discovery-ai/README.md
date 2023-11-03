# Gen3 Discovery AI Configuration

Expects configuration in a `gen3-discovery-ai` folder relative to 
where the `manifest.json` is. 

Expects secrets setup in `g3auto/gen3-discovery-ai` folder
 - `credentials.json`: Google service account key if using a topic with Google Vertex AI
 - `env`: .env file contents for service configuration (see service repo for a default one)

## Populating Disc for In-Memory Vectordb Chromadb

In order to setup pre-configured topics, we need to load a bunch of data 
into Chromadb (which is an inmem vectordb with an option to persist to disk).

To load topics consistently, we setup an S3 bucket to house the persisted 
data for the vectordb.

### Getting data into S3

We could support more than TSVs in the future, but for now that's the only automated support.

Move TSVs of data into the configuration in cdis-manifest. The expectation is that for Chromadb loading, the 
files are placed in a `gen3-discovery-ai/knowledge/tsvs` folder relative to 
where the `manifest.json` is. For example:
`~/cdis-manifest/avantol.planx-pla.net/gen3-discovery-ai/gen3-discovery-ai/knowledge/tsvs`

You can rsync from local if you have files locally.

See the Gen3 Discovery AI service repo README for more info.

### Getting data from S3 in mem

We specify a path for Chromadb to use for persisted data and when it sees 
data there, it loads it in. So the deployment automation aws syncs the bucket
and then calls a script to load the files into the in-mem vectorstore from there. 