# TL;DR

This folder holds kubernetes deployment and service resources for [Guppy](https://github.com/uc-cdis/guppy).
Configure and launch Guppy with `gen3 kube-setup-guppy`.

Guppy also imports configuration for the commons' manifest. The optional `tier_access_level` property in the `global` object of `manifest.json` determines the access level of a common and thus affects the behavior of Guppy. Valid options for `tier_access_level` are `libre`, `regular` and `private`. Common will be treated as `private` by default.

For `regular` level data commons, there's another configuration environment variable `tier_access_limit`, which is the minimum visible count for aggregation results. By default set to 1000. 