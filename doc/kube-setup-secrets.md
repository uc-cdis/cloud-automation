# TL;DR

Create most of the config maps and secrets required for a gen3 stack - including the `manifest-*` configmaps,
and the `creds-*` secrets.  With the notable exception of the `manifest-*` configmaps - `kube-setup-secrets` only
creates a secret or configmap if it does not yet exist - it does
not update a secret or configmap that already exists.
