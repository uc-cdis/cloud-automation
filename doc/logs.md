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

Save aggregations from yesterday to the `gen3-aggs-daily` index.

```
$ gen3 logs save daily
```

### `gen3 logs history daily`

Retrieve aggregations from the `gen3-aggs-daily` index.

```
$ gen3 logs history daily "start=-7 days" "vpc=all"
```

### `gen3 logs snapshot`

Snapshot the logs of currently running pods excluding jupyterhub to `.gz` files.
