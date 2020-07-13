# TL;DR

Bootstrap the configuration for a new commons.
Requires that `kubectl` is in the path, and set
to a context that references the namespace in which
to deploy the commons.

## Use

Typically used like this:

```
gen3 bootstrap template > bootstrap.json
# edit bootstrap.json
gen3 bootstrap go ./bootstrap.json
```

### `gen3 bootstrap template`

Generate a template config file that can be filled with values,
then provided to the other bootstrap subcommands.

```
gen3 bootstrap template
```


### `gen3 bootstrap go $theConfigFile`

Generate a subset of the config files required to deploy a Gen3
commons under the current kubectl namespace.
