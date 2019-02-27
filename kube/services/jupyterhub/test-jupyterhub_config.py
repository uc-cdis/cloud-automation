import os

class MockNull:
  pass

class MockConfig:
  def __init__(self):
    self.JupyterHub=MockNull()
    self.KubeSpawner=MockNull()
    self.RemoteUserAuthenticator=MockNull()

# read jupyterhub-config.py - for later eval
filePath=os.path.dirname(__file__) + '/jupyterhub_config.py'
with open(filePath) as f:
  configPy=f.read()

def test_config():
  global configPy
  c=MockConfig()
  os.environ['POD_NAMESPACE'] = 'bogus_namespace'
  os.environ['HOSTNAME'] = 'bogus_hostname'
  exec(configPy)
  assert len(c.KubeSpawner.volumes) > 0
