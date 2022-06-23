# TL;DR

Setup a kubecost cluster


## Use

### `gen3 kube-setup-kubecost master create`

Creates a master kubecost cluster

Requires the following `key value` arguments

* `--slave-account-id` - the account id of the slave kubecost cluster
* `--kubecost-token` - The token for the kubecost cluster
* `--slave-vpc-name` - The VPC name of the slave cluster
* `--slave-user-key` - The AWS_ACCESS_KEY of the user created in the slave setup
* `--slave-user-secret` - The AWS_SECRET_ACCESS_KEY of the user created in the slave setup

Optional `key value` arguments

* `--force` - defaults to false, set --force true to force helm upgrade
* `--disable-prometheus` - defaults to false, set --disable-prometheus true to disbale prometheus and use current setup
* `--prometheus-namespace` - The namespace of the current prometheus, required if kubecost prometheus is disabled
* `--prometheus-service` - The service name of the current prometheus, required if kubecost prometheus is disabled

Ex:

``` bash
gen3 kube-setup-kubecost master create --slave-account-id 1234567890 --kubecost-token abcdefghijklmnop12345 --slave-vpc-name test-vpc --slave-user-key AKIAZBCDEFG --slave-user-secret abcdefghigjlmnop --force true
```

### `gen3 kube-setup-kubecost slave create`

Creates a slave kubecost cluster


Requires the following `key value` arguments

* `--s3-bucket` - the centralized s3 bucket of the master kubecost cluster
* `--kubecost-token` - The token for the kubecost cluster

Optional `key value` arguments

* `--force` - defaults to false, set --force true to force helm upgrade
* `--disable-prometheus` - defaults to false, set --disable-prometheus true to disbale prometheus and use current setup
* `--prometheus-namespace` - The namespace of the current prometheus, required if kubecost prometheus is disabled
* `--prometheus-service` - The service name of the current prometheus, required if kubecost prometheus is disabled

Ex:

``` bash
gen3 kube-setup-kubecost slave create --s3-bucket test-kubecost-bucket --kubecost-token abcdefghijklmnop12345 --force true
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
