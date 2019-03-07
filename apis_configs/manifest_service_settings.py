from manifest_service.api import app
from os import environ
import config_helper

APP_NAME='manifest_service'

def load_json(file_name):
  return config_helper.load_json(file_name, APP_NAME)

conf_data = load_json('creds.json')
config = app.config

config['OIDC_ISSUER'] = 'https://%s/user' % conf_data['hostname']
config['FENCE_USER_INFO_URL'] = 'https://%s/user/user' % conf_data['hostname']
config['MANIFEST_BUCKET_NAME'] = conf_data['manifest_bucket_name']

application = app
application.debug = (environ.get('GEN3_DEBUG') == "True")