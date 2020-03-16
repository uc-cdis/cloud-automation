# TL;DR

Helper to cycle nodes in a kubernetes cluster

## Usage

You can cycle all nodes in a cluster given a interval, or you can just cycle a single node

### For a single node:

```bash
gen3 workers-cycle -s <node-name>
```

The node name can be obtained by listing them with kubect

EX:
```bash
$ kubectl get node
NAME                              STATUS   ROLES    AGE   VERSION
ip-192-168-151-155.ec2.internal   Ready    <none>   10m   v1.14.9-eks-1f0ca9
ip-192-168-152-162.ec2.internal   Ready    <none>   25m   v1.14.9-eks-1f0ca9
```

Any of those names would work like:

```bash
gen3 workers-cycle -s ip-192-168-151-155.ec2.internal
```


### For all the nodes in a cluster

```bash
gen3 workers-cycle -a <interval>
```

Where interval is the amount of seconds to wait until next run

```bash
gen3 workers-cycle -a 500
```



### Variants

```bash
gen3 workers-cycle --single ip-192-168-151-155.ec2.internal
gen3 workers-cycle --single=ip-192-168-151-155.ec2.internal
```

```bash
gen3 workers-cycle --all 500
gen3 workers-cycle --all=500
```


## Considerations

If you are going to cycle all the nodes in a cluster, try to provide an interval long enough for a new node to come into the cluster before the next run, specially if running it on production. Four minutes should be suffice.

Also, it's recommended that if you are cycling all nodes, to run this commmand in a tmux session or screen just in case you lose connection to the adminVM




 
