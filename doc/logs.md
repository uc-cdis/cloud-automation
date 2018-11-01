# TL;DR

Help for search the elastic search logs database.
Must set the `LOGPASSWORD` environment variable to access the db.
```
export LOGPASSWORD=XXXXX
gen3 logs raw
```

## Use

### `gen3 logs raw`

Accepts the following `key=value` arguments
* `page=number|number-number|all` - default `0`
* `vpc=$vpc_name|all` - default `${vpc_name:-all}`
* `service=name|all` - default `revproxy`
* `start=datetime` - default `yesterday`
* `end=datetime` - default `tomorrow`
* `format=raw|json` - default `raw`

Ex:
```
$ gen3 logs
$ gen3 logs page=0-1
$ gen3 logs page=all
$ gen3 logs vpc=devplanetv1 service=fence format=json start=2018/10/01
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
