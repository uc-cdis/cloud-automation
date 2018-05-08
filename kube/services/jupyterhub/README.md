# JupyterHub

This service provides a JupyterHub statefulset enabling users to launch Jupyter notebook pods.

# Deployment
Use latest cloud-automation, update revproxy if it's outdated, then:
```
gen3 kube-setup-jupyterhub
```

Update ELB for revproxy to remove http listener, update https listen's protocol to SSL, keep rest of the config same. This is **temporary solution**, should be solved by https://github.com/uc-cdis/cloud-automation/issues/178

Update [portal](https://github.com/uc-cdis/data-portal/blob/master/src/localconf.js#L98) for this commons to include workspace nav.

# AuthZ

AuthZ is provided by the Fence service utilizing the `auth-proxy` endpoint in the reverse proxy service. Currently that endpoint checks if the user is listed with any sort of privilages in `user.yaml`. A user without read access to any project would still qualify for JupyterHub access if they are listed in `user.yaml`. 

JupyterHub is set up to use the REMOTE_USER http header as the username for the user. JupyterHub trusts anything sent in REMOTE_USER so the revproxy must take care to only set it for authenticated users when proxying to the JupyterHub service.

# User Pods
The user pods are launched into the `jupyter-pods` namespace.

# More Info

https://github.com/jupyterhub/jupyterhub

https://github.com/jupyterhub/kubespawner
