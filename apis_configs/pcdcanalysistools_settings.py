from PcdcAnalysisTools.api import app, app_init
from os import environ
import config_helper

APP_NAME='PcdcAnalysisTools'
def load_json(file_name):
  return config_helper.load_json(file_name, APP_NAME)

conf_data = load_json('creds.json')
config = app.config

config["AUTH"] = 'https://auth.service.consul:5000/v3/'
config["AUTH_ADMIN_CREDS"] = None
config["INTERNAL_AUTH"] = None

# SIGNPOST is deprecated, replaced by INDEX_CLIENT (sheepdog>=1.1.12)
config['SIGNPOST'] = {
    'host': environ.get('SIGNPOST_HOST', 'http://indexd-service'),
    'version': 'v0',
    'auth': ('indexd_client', conf_data.get('indexd_password', '{{indexd_password}}')),
}
config["INDEX_CLIENT"] = {
    'host': environ.get('INDEX_CLIENT_HOST', 'http://indexd-service'),
    'version': 'v0',
    'auth': ('indexd_client', conf_data.get('indexd_password', '{{indexd_password}}')),
}
config["FAKE_AUTH"] = False
config["PSQLGRAPH"] = {
    'host': conf_data['db_host'],
    'user': conf_data['db_username'],
    'password': conf_data['db_password'],
    'database': conf_data['db_database'],
}

config['HMAC_ENCRYPTION_KEY'] = conf_data.get('hmac_key', '{{hmac_key}}')
config['FLASK_SECRET_KEY'] = conf_data.get('gdcapi_secret_key', '{{gdcapi_secret_key}}')
config['PSQL_USER_DB_CONNECTION'] = 'postgresql://%s:%s@%s:5432/%s' % tuple([ conf_data.get(key, key) for key in ['fence_username', 'fence_password', 'fence_host', 'fence_database']])
config['OIDC_ISSUER'] = 'https://%s/user' % conf_data['hostname']

config['OAUTH2'] = {
    'client_id': conf_data.get('oauth2_client_id', '{{oauth2_client_id}}'),
    'client_secret': conf_data.get('oauth2_client_secret', '{{oauth2_client_secret}}'),
    'api_base_url': 'https://%s/user/' % conf_data['hostname'],
    'authorize_url': 'https://%s/user/oauth2/authorize' % conf_data['hostname'],
    'access_token_url': 'https://%s/user/oauth2/token' % conf_data['hostname'],
    'refresh_token_url': 'https://%s/user/oauth2/token' % conf_data['hostname'],
    'client_kwargs': {
        'redirect_uri': 'https://%s/api/v0/oauth2/authorize' % conf_data['hostname'],
        'scope': 'openid data user',
    },
    # deprecated key values, should be removed after all commons use new oidc
    'internal_oauth_provider': 'http://fence-service/oauth2/',
    'oauth_provider': 'https://%s/user/oauth2/' % conf_data['hostname'],
    'redirect_uri': 'https://%s/api/v0/oauth2/authorize'  % conf_data['hostname']
}
config['USER_API'] = 'http://fence-service/'
# option to force authutils to prioritize USER_API setting over the issuer from
# token when redirecting, used during local docker compose setup when the
# services are on different containers but the hostname is still localhost
config['FORCE_ISSUER'] = True

if environ.get('DICTIONARY_URL'):
    config['DICTIONARY_URL'] = environ.get('DICTIONARY_URL')
else:
    config['PATH_TO_SCHEMA_DIR'] = environ.get('PATH_TO_SCHEMA_DIR')

app_init(app)
application = app
application.debug = (environ.get('GEN3_DEBUG') == "True")
