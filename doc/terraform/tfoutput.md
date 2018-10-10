# TL;DR

Wrapper around `terraform output`

## Use

```
  gen3 tfoutput [variable-name]:
    Run *terraform output* in the current workspace to log the current environment's output variables,
    and generate some supporting files.  
    A typical command line is:
       terraform output -json > vpcdata.json
```
