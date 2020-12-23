# TL;DR

Disable the portal, and display an "under maintenance" page instead.

## Use

Configure a commons to server a maintenance page like this:

* deploy the dashboard service to the commons if not already running
```
gen3 kube-setup-dashboard
```

* deploy an "under maintenance" page to the [dashboard](./dashboard.md)
    - install `manifest-folder/dashboard/Public/maintenance-page/index.html` via the normal `cdis-manifest` PR process
    - `gen3 dashboard gitops-sync` to deploy files to the dashboard
    - note: there is a sample maintenance page under `cloud-automation/files/dashboard/maintenance-page/`, and you may customize it with different logo images
* enable the the maintenance page by setting `global.maintenance_mode` to `on` in the `manifest.json`
    - you can make and revoke this change locally on the admin vm
    - `gen3 kube-setup-revproxy` to update the proxy

* when maintenance mode is enabled, then web pages normally served by the portal are redirected to the maintenance page - ex: https://commons.org/ redirects to https://commons.org/dashboard/Public/maintenance-page/index.html
* a developer can bypass the maintenance page, and access the portal for testing by setting the `devmode` cookie in the browser console - ex: `document.cookie = 'devmode=on;path=/'`

