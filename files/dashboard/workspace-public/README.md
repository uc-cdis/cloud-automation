# TL;DR

Little landing page for the workspace.gen3.org parent account.
[This document](https://docs.google.com/document/d/10_Rv-HWAvjvt8QQhA_0e5GIdI2M0rOBDvc5IA5zd8M0/edit#heading=h.ra5thdn8e3xr) provides an overview of the multi-account workspace design.

## Deployment

Deploy the workspace app to the root of the dashboard `Public/` space:
```
mkdir -p "$(gen3 gitops folder)/dashboard/Public"
rsync -av "$GEN3_HOME/files/dashboard/workspace-public/src/" "$(gen3 gitops folder)/dashboard/Public/"
gen3 dashboard gitops-sync
```

Configure the reverse proxy to redirect non-api traffic to the dashboard:
```
jq -r '.global.portal_app = "GEN3-WORKSPACE-PARENT"' < "$(g3k_manifest_path)" | tee "$(g3k_manifest_path).new"
mv "(g3k_manifest_path).new" "(g3k_manifest_path)"
```
