# TL;DR

Setup a kubecost cluster


## Use

### `gen3 kube-setup-kubecost master create`

Creates a master kubecost cluster

Requires the following `key value` arguments

* `--slave-account-id` - the account id of the slave kubecost cluster
* `--kubecost-token` - The token for the kubecost cluster

Optional `key value` arguments

* `--force` - defaults to false, set --force true to force helm upgrade
* `--disable-prometheus` - defaults to false, set --disable-prometheus true to disbale prometheus and use current setup
* `--prometheus-namespace` - The namespace of the current prometheus, required if kubecost prometheus is disabled
* `--prometheus-service` - The service name of the current prometheus, required if kubecost prometheus is disabled

Ex:

``` bash
gen3 kube-setup-kubecost master create --slave-account-id 1234567890 --kubecost-token abcdefghijklmnop12345 --force true
```

### `gen3 kube-setup-kubecost slave create`

Creates a slave kubecost cluster

$s3Bucket || -z $parentAccountId || -z $kubecostToken || -z $parentVPC || -z $childVPC

Requires the following `key value` arguments

* `--parent-vpc` - the vpc id of the master kubecost cluster
* `--child-vpc` - the vpc id of the slave kubecost cluster
* `--s3-bucket` - the centralized s3 bucket of the master kubecost cluster 
* `--parent-account-id` - the account id of the master cluster
* `--kubecost-token` - The token for the kubecost cluster

Optional `key value` arguments

* `--force` - defaults to false, set --force true to force helm upgrade
* `--disable-prometheus` - defaults to false, set --disable-prometheus true to disbale prometheus and use current setup
* `--prometheus-namespace` - The namespace of the current prometheus, required if kubecost prometheus is disabled
* `--prometheus-service` - The service name of the current prometheus, required if kubecost prometheus is disabled

Ex:

``` bash
gen3 kube-setup-kubecost slave create --parent-vpc vpc-12345 --child-vpc vpc23456 --s3-bucket test-kubecost-bucket --parent-account-id 1234567890 --kubecost-token abcdefghijklmnop12345 --force true
```

### `gen3 kube-setup-kubecost standalone create`

Creates a standalone kubecost cluster

Requires the following `key value` arguments

* `--kubecost-token` - The token for the kubecost cluster

Optional `key value` arguments

* `--force` - defaults to false, set --force true to force helm upgrade
* `--disable-prometheus` - defaults to false, set --disable-prometheus true to disbale prometheus and use current setup
* `--prometheus-namespace` - The namespace of the current prometheus, required if kubecost prometheus is disabled
* `--prometheus-service` - The service name of the current prometheus, required if kubecost prometheus is disabled

Ex:

``` bash
gen3 kube-setup-kubecost standalone create --kubecost-token abcdefghijklmnop12345 --force true
```

### `gen3 kube-setup-kubecost delete`

Deletes a running kubecost deployment and destroys the associated infra

Ex:

``` bash
gen3 kube-setup-kubecost delete
```
