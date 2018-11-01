# TL;DR

Query the elastic search logs database.
Must set the `LOGPASSWORD` environment variable to access the db.
```
export LOGPASSWORD=XXXXX
gen3 logs raw
```

## Use

### `gen3 logs raw`

Accepts the following `key=value` arguments
* `page=number|number-number|all` - default `0`
* `vpc=$vpc_name|all` - default `${vpc_name:-all}` - see `gen3 logs vpc` below
* `service=name|all` - default `revproxy`
* `start=datetime` - default `yesterday`
* `end=datetime` - default `tomorrow`
* `format=raw|json` - default `raw`

The following variables are also available when search `revproxy` service logs:
* `user=uid:number,email` - ex: `user=uid:5,frickjack@uchicago.edu` - see `gen3 logs user` below
* `visitor=visitor_id` - corresponding to the `visitor` cookie
* `session=session_id` - corresponding to the `session` cookie

Ex:
```
$ gen3 logs raw
$ gen3 logs raw page=0-1
$ gen3 logs raw page=all
$ gen3 logs raw vpc=devplanetv1 service=fence format=json start=2018/10/01
$ gen3 logs raw "user=$(gen3 logs user | grep reubenonrye)"
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