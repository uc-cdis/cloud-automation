# Gen3 Discovery AI

## Populating Disc for In-Memory Vectordb Chromadb

In order to setup pre-configured topics, we need to load a bunch of data 
into Chromadb (which is an inmem vectordb with an option to persist to disk).

To load topics consistently, we setup an S3 bucket to house the persisted 
vectordb. 

### Getting data into S3

Run the service elsewhere, load the data, and persist it to disk. Then move those
files from disk into the VM. The expectation is that for Chromadb loading, the 
files are placed in a `gen3-discovery-ai/knowledge/chromadb` folder relative to 
where the `manifest.json` is. For example:
`~/cdis-manifest/avantol.planx-pla.net/gen3-discovery-ai/gen3-discovery-ai/knowledge/chromadb`

You can rsync from local if you've generated it locally.

#### IMPORTANT: Use the same service image to generate the data locally as is used in the environment

> IMPORTANT NOTE: There are some oddities with using the persist to disk across different OS's with different security packages.

You should run the store knowledge commands that eventually create the persisted
disk from within the SAME IMAGE that gets deployed. 

One way to do this is as follows:

* Use docker to build the image locally and run it with a volume mount
* exec into the running container
* run commands necessary to load the knowledge
* check the location of the volume mount on your host system for the persisted data
* rsync that data to the data commons (or check into cdis-manifest)

See the Gen3 Discovery AI service repo README for more info.

```
rsync -re ssh --progress ~/repos/gen3-discovery-ai/knowledge/ avantol@cdistest_dev.csoc:~/cdis-manifest/avantol.planx-pla.net/gen3-discovery-ai/knowledge/chromadb
```

### Getting data from S3 in mem

We specify a path for Chromadb to use for persisted data and when it sees 
data there, it loads it in. 