# workspace token service
Microservice that's responsible for issuing short lived tokens to workers inside a workspace environment.
Each type of workspace environment should have a corresponding auth mechanism for the service to check the identity of a worker.
Currently has a k8s auth plugin that supports workers deployed as k8s pod with username annotation.

[architecture](https://raw.githubusercontent.com/uc-cdis/cloud-automation/master/kube/services/wts/architecture.svg)
