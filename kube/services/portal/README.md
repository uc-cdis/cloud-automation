# TL;DR

This folder holds kubernetes deployment and service resources for the gen3 web portal.
The portal also imports configuratoin for the commons' manifest (see below).
Configure and launch the portal with `gen3 kube-setup-portal`.

# Portal customization

Several flags and files in a deployment [manifest](https://github.com/uc-cdis/cdis-manifest) are available to customize the behavior and appearance of the gen3 web [portal](https://github.com/uc-cdis/data-portal).

First, the `portal_app` property in the `global` object of `manifest.json` 
determines which "profile" the portal runs with.  The portal's profile
includes customizations necessary for the common's dictionary, so the `bhc` protal_app
customizes the portal to work with the brain commons' dictionary.

The portal includes support for several customization profiles in its code base in various files under the [data/config](https://github.com/uc-cdis/data-portal/tree/master/data/config)
and [custom/](https://github.com/uc-cdis/data-portal/tree/master/custom) folders.
An environment may also define its own `gitops` profile by installing files
under a manifest's `portal/` folder (for example - [reuben.planx-pla.net/portal](https://github.com/uc-cdis/gitops-dev/tree/master/reuben.planx-pla.net))
that override the default `gitops` profile defined in cloud-automation 
[here](https://github.com/uc-cdis/cloud-automation/tree/master/kube/services/portal/defaults):
```
$ ls -1F kube/services/portal/defaults/
gitops-createdby.png
gitops.css
gitops-favicon.ico
gitops.json
gitops-logo.png
```
