# TL;DR

Wrapper around `terraform output`

## Use

```
  gen3 tfoutput [variable-name]
```

A wrapper around [terraform output](https://www.terraform.io/intro/getting-started/outputs.html) - 
runs *terraform output* in the current workspace to log the current environment's output variables,
and generate some supporting files.  
A typical command line is:
    `gen3 tfoutput -json > vpcdata.json`

```
$ gen3 tfoutput ssh_config
Host login.planxplanetv1
   ServerAliveInterval 120
   HostName XX.XXX.XXX.XXX
   User ubuntu
   ForwardAgent yes

Host k8s.planxplanetv1
   ServerAliveInterval 120
   HostName 172.XX.XX.XX
   User ubuntu
   ForwardAgent yes
   ProxyCommand ssh ubuntu@login.planxplanetv1 nc %h %p 2> /dev/null

```

