'''
Kind of a weird file - pretty sure jupyterhub just eval's this after defining c
'''

import os
from kubernetes import client

def modify_pod_hook(spawner, pod):
    '''
    A container must be run with additional privileges in order to mount a FUSE filesystem.
    https://github.com/jupyterhub/zero-to-jupyterhub-k8s/issues/379
    '''
    pod.spec.containers[0].security_context = client.V1SecurityContext(
        privileged=True,
        capabilities=client.V1Capabilities(
            add=['SYS_ADMIN', 'MKNOD']
        )
    )
    return pod

c.JupyterHub.base_url = '/lw-workspace'
c.JupyterHub.confirm_no_ssl = True
c.JupyterHub.db_url = 'sqlite:////etc/config/jupyterhub.sqlite'
c.JupyterHub.cookie_secret_file = '/etc/config/jupyterhub_cookie_secret'
c.JupyterHub.authenticator_class = 'jhub_remote_user_authenticator.remote_user_auth.RemoteUserAuthenticator'
#c.ConfigurableHTTPProxy.debug = True
c.JupyterHub.log_level = 'INFO'
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
c.KubeSpawner.uid = 1000
c.KubeSpawner.fs_gid = 100
c.KubeSpawner.storage_pvc_ensure = True
c.KubeSpawner.storage_capacity = '10Gi'
c.KubeSpawner.pvc_name_template = 'claim-{username}{servername}'
c.KubeSpawner.storage_class = 'jupyter-storage'
c.KubeSpawner.volumes = [
    {
        'name': 'volume-{username}{servername}',
        'persistentVolumeClaim': {
            'claimName': 'claim-{username}{servername}'
        }
    },
    {
        'name': 'fuse-{username}{servername}',
        'hostPath' : {
            'path' : '/dev/fuse'
        }
    }
]
c.KubeSpawner.volume_mounts = [
    {
        'mountPath': '/home/jovyan/pd',
        'name': 'volume-{username}{servername}'
    },
    {
        'mountPath': '/dev/fuse',
        'name': 'fuse-{username}{servername}',
    }
]
# c.KubeSpawner.extra_containers = [{
#     'name' : 'fuse-container', 
#     'volumeDevices' :  [ 
#         { 'devicePath' : '/dev/fuse', 'name' : 'fuse-{username}{servername}' }
#     ],
#     'command' : ['sh', '-c', 'while [ true ]; sleep 10; done'],
#     'image': 'quay.io/cdis/fuse_container:1.0',
#     'securityContext': { 'privileged' : 'true' },
#     'capabilities': {'add' : ['SYS_ADMIN', 'MKNOD']}
# }]
c.KubeSpawner.hub_connect_ip = 'jupyterhub-service.%s' % (os.environ['POD_NAMESPACE'])
c.KubeSpawner.hub_connect_port = 8000
c.KubeSpawner.profile_list = [
    {
        'display_name': 'Bioinfo - Python/R - 0.5 CPU 256M Mem',
        'kubespawner_override': {
            # TODO: Change this back. But need this here for now for integration test purposes.
            'singleuser_image_spec': 'quay.io/occ_data/jupyternotebook:feat_workspace-tools',
            'cpu_limit': 0.5,
            'mem_limit': '256M',
        }
    },
    {
        'display_name': 'Bioinfo - Python/R - 1.0 CPU 1.5G Mem',
        'kubespawner_override': {
            'singleuser_image_spec': 'quay.io/occ_data/jupyternotebook:1.7.2',
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
# TODO: Remove this below line. But need this here for now for integration test purposes.
c.KubeSpawner.image_pull_policy = 'Always' 
c.KubeSpawner.modify_pod_hook = modify_pod_hook
c.KubeSpawner.cmd = 'start-singleuser.sh'
c.KubeSpawner.args = ['--allow-root --hub-api-url=http://%s:%d%s/hub/api --hub-prefix=https://%s%s/' % (
    c.KubeSpawner.hub_connect_ip, c.KubeSpawner.hub_connect_port, c.JupyterHub.base_url, os.environ['HOSTNAME'], c.JupyterHub.base_url)]
# First pulls can be really slow, so let's give it a big timeout
c.KubeSpawner.start_timeout = 60 * 10
c.KubeSpawner.tolerations = [ 
    {
        'key': 'role',
        'value': 'jupyter',
        'operator': 'Equal',
        'effect': 'NoSchedule',
    }
]
c.KubeSpawner.node_selector = { 'role': 'jupyter' }
# Don't try to cleanup servers on exit - since in general for k8s, we want
# the hub to be able to restart without losing user containers
c.JupyterHub.cleanup_servers = False
c.JupyterHub.ip = '0.0.0.0'
c.JupyterHub.hub_ip = '0.0.0.0'
c.RemoteUserAuthenticator.auth_refresh_age = 1
c.RemoteUserAuthenticator.refresh_pre_spawn = True