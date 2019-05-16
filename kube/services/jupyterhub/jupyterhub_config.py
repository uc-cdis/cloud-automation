"""
Kind of a weird file - pretty sure jupyterhub just eval's this after defining c
"""

import os
import json

c.JupyterHub.base_url = "/lw-workspace"
c.JupyterHub.confirm_no_ssl = True
c.JupyterHub.db_url = "sqlite:////etc/config/jupyterhub.sqlite"
c.JupyterHub.cookie_secret_file = "/etc/config/jupyterhub_cookie_secret"
c.JupyterHub.authenticator_class = (
    "jhub_remote_user_authenticator.remote_user_auth.RemoteUserAuthenticator"
)
# c.ConfigurableHTTPProxy.debug = True
c.JupyterHub.log_level = "INFO"
c.JupyterHub.services = [
    {
        "name": "cull-idle",
        "admin": True,
        "command": "python /usr/local/bin/cull_idle_servers.py --timeout=3600".split(),
    }
]
c.JupyterHub.spawner_class = "kubespawner.KubeSpawner"
if os.environ["POD_NAMESPACE"] == "default":
  c.KubeSpawner.namespace = "jupyter-pods"
else:
  c.KubeSpawner.namespace = "jupyter-pods-" + os.environ["POD_NAMESPACE"]
c.KubeSpawner.cpu_limit = 1.0
c.KubeSpawner.mem_limit = "1.5G"
# c.KubeSpawner.debug = False
c.KubeSpawner.notebook_dir = "/home/jovyan/pd"
c.KubeSpawner.uid = 1000
c.KubeSpawner.fs_gid = 100
c.KubeSpawner.storage_pvc_ensure = True

if os.environ.get("NOTEBOOK_STORAGE_CAPACITY"):
  c.KubeSpawner.storage_capacity = os.environ.get("NOTEBOOK_STORAGE_CAPACITY")
else:
  c.KubeSpawner.storage_capacity = "10Gi"

c.KubeSpawner.pvc_name_template = "claim-{username}{servername}"
c.KubeSpawner.storage_class = "jupyter-storage"
c.KubeSpawner.volumes = [
    {
        'name': 'volume-{username}{servername}',
        'persistentVolumeClaim': { 'claimName': 'claim-{username}{servername}' }
    },
    {
	'name': 'shared-data',
	'emptyDir': {}
    }
]

c.KubeSpawner.volume_mounts = [
    { 'mountPath': '/home/jovyan/pd', 'name': 'volume-{username}{servername}' },
    { 'mountPath' : '/data', 'name' : 'shared-data', 'mountPropagation' : 'HostToContainer' }
]
c.KubeSpawner.hub_connect_ip = "jupyterhub-service.%s" % (os.environ["POD_NAMESPACE"])
c.KubeSpawner.hub_connect_port = 8000
#c.KubeSpawner.image_pull_policy = "Always"
raw_profiles = os.environ.get("JUPYTER_CONTAINERS", None)
if raw_profiles:
    profiles = json.loads(raw_profiles)
    profile_list = [
        {
            "display_name": "{} {:.1f} CPU {} Mem".format(
                x["name"], x["cpu"], x["memory"]
            ),
            "kubespawner_override": {
                "image_spec": x["image"],
                "cpu_limit": x["cpu"],
                "mem_limit": x["memory"],
            },
        }
        for x in profiles
    ]
    c.KubeSpawner.profile_list = profile_list
else:
    c.KubeSpawner.profile_list = [
        {
            "display_name": "Bioinfo - Python/R - 0.5 CPU 256M Mem",
            "kubespawner_override": {
                "image_spec": "quay.io/occ_data/jupyternotebook:1.7.2",
                "cpu_limit": 0.5,
                "mem_limit": "256M",
            },
        }
    ]
c.KubeSpawner.cmd = "start-singleuser.sh"
c.KubeSpawner.args = [
    "--allow-root",
    "--hub-api-url=http://%s:%d%s/hub/api"
    % (
        c.KubeSpawner.hub_connect_ip,
        c.KubeSpawner.hub_connect_port,
        c.JupyterHub.base_url,
    ),
    "--hub-prefix=https://%s%s/" % (os.environ["HOSTNAME"], c.JupyterHub.base_url),
]
c.KubeSpawner.lifecycle_hooks = {
    "postStart": {
        "exec": {
            "command": [
                "/bin/sh",
                "-c",
                "rm -rf /home/jovyan/pd/dockerHome; ln -s $(pwd) /home/jovyan/pd/dockerHome; mkdir -p /home/$NB_USER/.jupyter/custom; echo \"define(['base/js/namespace'], function(Jupyter){Jupyter._target = '_self';})\" >/home/$NB_USER/.jupyter/custom/custom.js; ln -s /data /home/jovyan/pd/; true",
            ]
        }
    }
}
# c.KubeSpawner.image_pull_policy = 'Always'
# First pulls can be really slow, so let's give it a big timeout
c.KubeSpawner.start_timeout = 60 * 10
c.KubeSpawner.tolerations = [
    {"key": "role", "value": "jupyter", "operator": "Equal", "effect": "NoSchedule"}
]
c.KubeSpawner.node_selector = {"role": "jupyter"}
# Don't try to cleanup servers on exit - since in general for k8s, we want
# the hub to be able to restart without losing user containers
c.JupyterHub.cleanup_servers = False
c.JupyterHub.ip = "0.0.0.0"
c.JupyterHub.hub_ip = "0.0.0.0"
c.RemoteUserAuthenticator.auth_refresh_age = 1
c.RemoteUserAuthenticator.refresh_pre_spawn = True

sidecar_image = os.environ.get("SIDECAR", 'quay.io/cdis/gen3fuse-sidecar:master')
c.KubeSpawner.extra_containers = [{
     'name' : 'fuse-container',
     'volumeMounts' :  [
         { 'mountPath' : '/data', 'name' : 'shared-data', 'mountPropagation' : 'Bidirectional' }
     ],
     'command' : ['su', '-c', 'env NAMESPACE="%s" HOSTNAME="%s" /home/jovyan/sidecarDockerrun.sh' % (os.environ["POD_NAMESPACE"], os.environ["HOSTNAME"]), '-s', '/bin/sh', 'jovyan'],
     'image': sidecar_image,
     'securityContext': { 'privileged' : True, 'runAsUser' : 0, 'runAsGroup' : 0 },
     'lifecycle': {'preStop': {'exec': {'command': ['su', '-c', 'cd /data; for f in *; do fusermount -u $f; rm -rf $f; done', '-s', '/bin/sh', 'jovyan']}}}
}]
