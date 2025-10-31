# TL;DR

kubectl 1.24.0 introduces a breaking change, so the older kubeconfig doesn't work anymore.

https://github.com/aws/aws-cli/issues/6920

Updates Kubeconfig API version, args, and command to get rid of the following error: 
error: exec plugin: invalid apiVersion "client.authentication.k8s.io/v1alpha1"

This error occurs when the client kubectl version is updated and the kubeconfig remains the same. 

This requires AWS cli v2.7.0 or higher.

## Use

### Run
```
gen3 update-kubeconfig
```


This command backs up existing kubeconfig file and regenerates a valid kubeconfig file using AWS cli. Also persists the current namespace to the context.


