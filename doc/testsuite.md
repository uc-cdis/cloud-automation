# TL;DR

Run through the complete testsuite include [g3k_testuite](./g3k_testsuite.md) and a terraform test suite that requires a properly configured `cdistest` environment.

## Local testing

```
export GEN3_HOME=path/to/cloud-automation
source "$GEN3_HOME/gen3/gen3setup.sh"
gen3 testsuite --filter local
```

## Examples

* Run the entire test suite
```
gen3 testsuite
```

* Run the tests tagged with the "local" tag - local test do not require a 
test environment (kubernetes and AWS) to test against
```
gen3 testsuite --filter local
```

* Run the tests tagged with either the "local" or the "klock" tag
```
gen3 testsuite --filter local,klock
```

* Run the terraform test suite, and override the AWS profile
```
gen3 testsuite --profile test2 --filter terraform
```

* Run particular test functions
```
gen3 testsuite --filter test_semver,test_colors
```