# Gen3 ETL
Gen3 ETL is designed to translate data from a graph data model stored in Postgresql database to flatten indices in ElasticSearch (ES) which supports the efficient way to query data from the front-end. 
## Transformer
Interestingly, choosing transformer is the most important thing in ETL, because transformer requires a specific format of input and output data.
Specifically to our use-case, Spark becomes one of the most advanced data processing technology, because its distributed architecture allows:
 1. processing data in parallel simply inside the horizontally scalable memory.
 2. iteratively processing data in multiple steps without reloading from data storage (disk). 
 3. streaming and integrating incremental data to an existing data source.

Hence, we choose Spark as a data transformer for a fast and scalable data processing. 

As discussed previously, there are multiple ways to extract data from database and load to Spark. One is directly generate and execute in parallel multiple SQL queries and load it to Spark's memory, another one is dumping the whole dataset to intermediate data storage like HDFS and then load text data stored in HDFS into Spark in parallel.  

Learning all the options that one of our collabators OICR tried (posted [here](https://softeng.oicr.on.ca/grant_guo/2017/08/14/spark/) ). We decided to go with similar strategy - dump postgres to HDFS and load HDFS to rdd/SPARK.
We decided to use [SQOOP](https://github.com/apache/sqoop) to dump the postgres database to HDFS. In order to dump postgresql database, SQOOP calls [CopyManager](https://jdbc.postgresql.org/documentation/publicapi/org/postgresql/copy/CopyManager.html).

Finally, we decided to use python instead of scala because cdis dev teams are much more comfortable with python programming. And since all the computation will be done in spark, we won't do any manipulation on the python level, the performance won't be a huge difference.

## Mapping file
Every ETL process is defined by a translation from the original dataset to the expected one. *Gen3-ETL* provides a neutral way with which you can:
 1. `aggregate, collect` data from mulitple nodes in original dataset to an individual one in the target dataset.
 2. `embed` some fields in high level node to lower level nodes or `extract` some particular fields from any specific node.

 ## Running ETL

 1. define mapping file and save that mapping file as `etlMapping.yaml` to the gitops repo. Format of the mapping file can be found [here](https://github.com/uc-cdis/tube#mapping-file)
 2. run `gen3 kube-setup-secrets` to create the new configmap. If the configmap exists, you must delete it first by running `kubectl delete configmap etl-mapping`
 3. run `gen3 roll spark`
 4. run `gen3 roll tube`
 5. waiting for `tube` pod ready and running `kubectl exec -it {tube-pod-name} -- bash`
 6. inside the `tube` pod run:
    - `python run_import.py` to import data from postgresql to HDFS in `spark` pod
    - then `python run_spark.py` to tranform data and put extracted data from HDFS to ElasticSearch.