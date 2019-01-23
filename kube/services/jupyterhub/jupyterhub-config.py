'''
Kind of a weird file - pretty sure jupyterhub just eval's this after defining c
'''

import os

c.JupyterHub.base_url = '/lw-workspace'
c.JupyterHub.confirm_no_ssl = True
c.JupyterHub.db_url = 'sqlite:////etc/config/jupyterhub.sqlite'
c.JupyterHub.cookie_secret_file = '/etc/config/jupyterhub_cookie_secret'
c.JupyterHub.authenticator_class = 'jhub_remote_user_authenticator.remote_user_auth.RemoteUserAuthenticator'
#c.ConfigurableHTTPProxy.debug = True
c.JupyterHub.log_level = 'DEBUG'
c.JupyterHub.services = [
    {
        'name': 'cull-idle',
        'admin': True,
        'command': 'python /usr/local/bin/cull_idle_servers.py --timeout=3600'.split(),
    }
]
c.JupyterHub.spawner_class = 'kubespawner.KubeSpawner'
c.KubeSpawner.namespace = 'jupyter-pods'
c.KubeSpawner.cpu_limit = 1.0
c.KubeSpawner.mem_limit = '1.5G'
#c.KubeSpawner.debug = False
c.KubeSpawner.notebook_dir = '/home/jovyan/pd'
c.KubeSpawner.singleuser_uid = 1000
c.KubeSpawner.singleuser_fs_gid = 1000
c.KubeSpawner.user_storage_pvc_ensure = True
c.KubeSpawner.user_storage_capacity = '10Gi'
c.KubeSpawner.pvc_name_template = 'claim-{username}{servername}'
c.KubeSpawner.user_storage_class = 'jupyter-storage'
c.KubeSpawner.volumes = [
    {
        'name': 'volume-{username}{servername}',
        'persistentVolumeClaim': {
            'claimName': 'claim-{username}{servername}'
        }
    }
]
c.KubeSpawner.volume_mounts = [
    {
        'mountPath': '/home/jovyan/pd',
        'name': 'volume-{username}{servername}'
    }
]
c.KubeSpawner.hub_connect_ip = 'jupyterhub-service.%s' % (os.environ['POD_NAMESPACE'])
c.KubeSpawner.hub_connect_port = 8000
c.KubeSpawner.profile_list = [
    {
        'display_name': 'Bioinfo - Python/R - 0.5 CPU 256M Mem',
        'kubespawner_override': {
            'singleuser_image_spec': 'quay.io/occ_data/jupyternotebook:1.6',
            'cpu_limit': 0.5,
            'mem_limit': '256M',
        }
    },
    {
        'display_name': 'Bioinfo - Python/R - 1.0 CPU 1.5G Mem',
        'kubespawner_override': {
            'singleuser_image_spec': 'quay.io/occ_data/jupyternotebook:1.6',
            'cpu_limit': 1.0,
            'mem_limit': '1.5G',
        }
    },
    {
        'display_name': 'Earth - Python - 0.5 CPU 256M Mem',
        'kubespawner_override': {
            'singleuser_image_spec': 'quay.io/occ_data/jupyter-geo:1.6',
            'cpu_limit': 0.5,
            'mem_limit': '256M',
        }
    },
    {
        'display_name': 'Earth - Python - 1.0 CPU 10.0G Mem',
        'kubespawner_override': {
            'singleuser_image_spec': 'quay.io/occ_data/jupyter-geo:1.6',
            'cpu_limit': 1.0,
            'mem_limit': '10.0G',
        }
    }
]
c.KubeSpawner.cmd = 'start-singleuser.sh'
c.KubeSpawner.args = ['--allow-root --hub-api-url=http://%s:%d%s/hub/api --hub-prefix=https://%s%s/' % (
    c.KubeSpawner.hub_connect_ip, c.KubeSpawner.hub_connect_port, c.JupyterHub.base_url, os.environ['HOSTNAME'], c.JupyterHub.base_url)]
# First pulls can be really slow, so let's give it a big timeout
c.KubeSpawner.start_timeout = 60 * 10
c.KubeSpawner.node_affinity_required = [
  
]
# Don't try to cleanup servers on exit - since in general for k8s, we want
# the hub to be able to restart without losing user containers
c.JupyterHub.cleanup_servers = False
c.JupyterHub.ip = '0.0.0.0'
c.JupyterHub.hub_ip = '0.0.0.0'
#c.Authenticator.admin_users = {'razorm@gmail.com'}
