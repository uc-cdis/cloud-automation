# TL;DR

Query the elastic search logs database.
Must set the `LOGPASSWORD` environment variable to access the db.
```
export LOGPASSWORD=XXXXX
gen3 logs raw
```

## Use

### `gen3 logs job`

Get the logs for a kubernetes cron job (usersync by default).

Accepts the following `key=value` arguments
* `page=number|number-number|all` - default `0`
* `vpc=$vpc_name|all` - default `${vpc_name:-all}` - see `gen3 logs vpc` below
* `jname=name` - job name prefix - default `usersync`
* `start=datetime` - default `yesterday`
* `end=datetime` - default `tomorrow`
* `format=raw|json` - default `raw`
* `fields=all|log|none` - default `log` if `aggs` is `no`, default `none` if `aggs` is `yes`

Ex:
```
$ gen3 logs job vpc=dcfprod jname=google
$ gen3 logs job vpc=all jname=user start='2 hours ago'
```

Note: `gen3 logs vpc` gives the available VPC codes

### `gen3 logs raw`

Get the logs for a gen3 service (revproxy by default).

Accepts the following `key=value` arguments
* `page=number|number-number|all` - default `0`
* `vpc=$vpc_name|all` - default `${vpc_name:-all}` - see `gen3 logs vpc` below
* `service=name|all` - default `revproxy`
* `proxy=fence|indexd|...|all` - default `all` - filters `revproxy` service results
* `start=datetime` - default `yesterday`
* `end=datetime` - default `tomorrow`
* `format=raw|json` - default `raw`
* `aggs=yes|no` - default `no` - aggregations
* `fields=all|log|none` - default `log` if `aggs` is `no`, default `none` if `aggs` is `yes`

The following variables are also available when search `revproxy` service logs:
* `user=uid:number,email` - ex: `user=uid:5,frickjack@uchicago.edu` - see `gen3 logs user` below
* `visitor=visitor_id` - corresponding to the `visitor` cookie
* `session=session_id` - corresponding to the `session` cookie
* `statusmin=0` - minimum http status, default 0
* `statusmax=1000` - max http status, default 100

Ex:
```
$ gen3 logs raw
$ gen3 logs raw vpc=dcfprod  # see: gen3 logs vpc
$ gen3 logs raw vpc=dcfprod fields=all 'labels=app:gen3job,job-name:usersync-*'
$ gen3 logs raw page=0-1
$ gen3 logs raw page=all
$ gen3 logs raw vpc=devplanetv1 service=fence format=json start=2018/10/01
$ gen3 logs raw "user=$(gen3 logs user | grep reubenonrye)"
$ gen3 logs raw statusmin=400
```

Note: the reverse proxy's logs are json format - which lends itself well
to post-query processing - ex:
```
cat /tmp/bla | (echo '['; while read -r line; do echo "$line" | jq -r .; echo ','; done; echo '{}]') | jq -r '. | map(select(.http_status_code > 100))'
```

### `gen3 logs curl`

Little `curl` wrapper that sets up the basic-auth creds and hostname,
takes the URL path from the first argument (or defaults to `_cat/indices`), then
passes through other args.

```
gen3 logs curl genomelprod-2019-w09/_mapping?pretty=true
```

If the URL includes the protocol, then assumes the hostname is given - ex:

```
gen3 logs curl https://www.google.com
```


### `gen3 logs curl200`

Like `gen3 logs curl`, but non-zero exit code if HTTP status is not 200.
Little different than `--fail`, because it sends the results to stderr.

```
gen3 logs curl200 https://www.google.com -X DELETE
```

### `gen3 logs curljson`

Like `gen3 logs curl200`, but fails if the response payload is not json - sending the results to stderr.

```
gen3 logs curl200 https://www.google.com -X DELETE
```

### `gen3 logs cloudwatch streams [group="environment"] [grep=""]`

Retrieve the 1000 cloudwatch streams with the most recent events, and optionally filter by name.

Ex 1:
```
gen3 logs cloudwatch streams grep=fence-deployment | tee ~/trash/streams.njson
```

Ex 2:
```
gen3 logs cloudwatch streams group=bhcprodv2 start='2 days ago' grep='fence-deployment'
```

### `gen3 logs cloudwatch events [group="environment"] stream1 stream2 ...`

Retrieve the events in the given streams of the given group.
Generates local files in the current directory for each stream.

```
gen3 logs cloudwatch events kubernetes.gen3.json.kubernetes.var.log.containers.wts-deployment-8545b5647c-bstw4_abby_wts-2d887daa161c23041e293c75582adb800252f38d88b7e4386069df3d58e19d47.log kubernetes.gen3.json.kubernetes.var.log.containers.wts-deployment-555944564c-fd5xf_marcelo_wts-fc7e5592229b5bea68778e2e681a55fb3711e9679cbd0561a7cc1db370aa5706.log
```

### `gen3 logs s3 start=yesterday end=tomorrow filter=raw prefix=...`

Retrieve the access logs from the given s3 logs bucket prefix.
 
#### file access count report

```
gen3 logs s3 start=2020-01-01 end=tomorrow prefix=s3://s3logs-s3logs-mjff-databucket-gen3/log/mjff-databucket-gen3 | grep 'username' | grep GET | awk '{ print $9 }' | sort | uniq -c
```

or

```
gen3 logs s3 start=2020-01-01 end=tomorrow filter=accessCount prefix=s3://s3logs-s3logs-mjff-databucket-gen3/log/mjff-databucket-gen3 
```

```
gen3 logs s3 start=2020-01-01 end=tomorrow filter=accessCount prefix=s3://s3logs-s3logs-mjff-databucket-gen3/log/mjff-databucket-gen3
```

or

```
gen3 logs s3 start=2020-01-01 end=tomorrow prefix=s3://s3logs-s3logs-mjff-databucket-gen3/log/mjff-databucket-gen3 | gen3 logs s3filter filter=accessCount
```


#### who downloaded what when

```
start=2020-01-01
end=tomorrow
for prefix in s3://s3logs-s3logs-mjff-databucket-gen3/log/mjff-databucket-gen3 s3://bhc-bucket-logs/ s3://bhcprodv2-data-bucket-logs/log/bhcprodv2-data-bucket/; do 
gen3 logs s3 start=$start end=$end prefix=$prefix | grep 'username' | grep GET | awk -v bucket=$prefix '{ print gensub(/\[/, "", "g", $3) "\t" $9 "\t" gensub(/&.*/, "", "g", gensub(/.+username=/, "", "g", $11)) "\t" bucket }' | sort
done
```

or

```
start=2020-01-01
end=tomorrow
for prefix in s3://s3logs-s3logs-mjff-databucket-gen3/log/mjff-databucket-gen3 s3://bhc-bucket-logs/ s3://bhcprodv2-data-bucket-logs/log/bhcprodv2-data-bucket; do 
gen3 logs s3 start=$start end=$end filter="whoWhatWhen" prefix=$prefix
done
```

or

```
start=2020-01-01
end=tomorrow
for prefix in s3://s3logs-s3logs-mjff-databucket-gen3/log/mjff-databucket-gen3 s3://bhc-bucket-logs/ s3://bhcprodv2-data-bucket-logs/log/bhcprodv2-data-bucket2020; do 
gen3 logs s3 start=$start end=$end prefix=$prefix | gen3 logs s3filter filter=whoWhatWhen prefix=$prefix
done
```

### `gen3 logs s3filter filter=raw prefix=unknown/`

Apply filters to an s3 logs stream.
See the examples under `gen3 logs s3 ...` ...


### `gen3 logs vpc`

List the valid values for the `vpc` argument to `gen3 logs raw` which restricts
query results to a particular kubernetes cluster by leveraging the cloudwatch logGroup
stored in each ES record.  Note that the default value for `vpc` is pulled from the `$vpc_name`
environment variable - which is set on the admin VM for each environment.

The output lists one vpc per line where the first two tokens of each line are the `vpcName` and one `hostname` associated with a commons running in that vpc:
```
vpcName hostname other descriptive stuff to grep on
```

Ex:
```
$ gen3 logs vpc | grep bhc 
bhcprodv2 data.braincommons.org cvb

$ bhcVpc="$(gen3 logs vpc | grep bhc | awk '{ print $1 }')
```

### `gen3 logs user`

List the user ids in the local commons (only works on the commons' admin vm).

Ex:
```
$ gen3 logs user | grep reuben
uid:11,reubenonrye@sandwich.edu
```

### `gen3 logs save daily`

Save unique-user aggregations from yesterday to the `gen3-aggs-daily` index.

```
$ gen3 logs save daily
```

### `gen3 logs history daily`

Retrieve unique-user aggregations from the `gen3-aggs-daily` index.

```
$ gen3 logs history daily "start=-7 days" "vpc=all"
```

### `gen3 logs history codes`

Retrieve response-code histogram for the given commons and date range.

```
$ gen3 logs history codes "start=-7 days" "vpc=bhcprodv2"
```

### `gen3 logs history rtimes`

Retrieve response-time histogram for the given commons and date range.

```
$ gen3 logs history rtimes "start=-7 days" "vpc=bhcprodv2"
```

### `gen3 logs history users`

Retrieve the number of unique users for the given commons and date range.

```
$ gen3 logs history rtimes "start=-7 days" "vpc=bhcprodv2"
```

### `gen3 logs snapshot`

Snapshot the logs of currently running pods excluding jupyterhub to `.gz` files.
