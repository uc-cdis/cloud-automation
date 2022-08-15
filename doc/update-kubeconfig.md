# TL;DR

Updates Kubeconfig API version, args, and command to get rid of the following error: 
error: exec plugin: invalid apiVersion "client.authentication.k8s.io/v1alpha1"

This error occurs when the client kubectl version is updated and the kubeconfig remains the same. 

## Use

### Run
```
gen3 update-kubeconfig
```

### Replaces API Version, args, and command in Kubeconfig
```
  - name: aws
    user:
      exec:
-       apiVersion: client.authentication.k8s.io/v1alpha1
-       command: heptio-authenticator-aws
-       args:
-         - "token"
-         - "-i"
-         - "oadc"
-         #- "-r"
-         #- "<role ARN>"
-       #env:
-         #- name: AWS_PROFILE
-         #  value: "<profile>"

  - name: aws
    user:
      exec:
+       apiVersion: client.authentication.k8s.io/v1beta1
+       args:
+       - --region
+       - us-east-1
+       - eks
+       - get-token
+       - --cluster-name
+       - oadc
+       command: aws

```

