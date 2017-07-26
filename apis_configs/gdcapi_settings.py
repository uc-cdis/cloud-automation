from gdcapi.api import app
from os import environ
# the below could be replaced with `from gcapi.api import app_init`,
# it's here only for extreme backwards compatibility and should
# someday be removed
try:
    from gdcapi.run import app_with_fake_auth as app_init 
except:
    from gdcapi.api import db_init as app_init

config = app.config

config["AUTH"] = 'https://auth.service.consul:5000/v3/'
config["AUTH_ADMIN_CREDS"] = None
config["INTERNAL_AUTH"] = None

# Signpost
config['SIGNPOST'] = {
    'host': environ.get('SIGNPOST_HOST', 'http://indexd-service.default'),
    'version': 'v0',
    'auth': ('gdcapi', '{{indexd_password}}'),
}
config["FAKE_AUTH"] = False
config["PSQLGRAPH"] = {
    'host': '{{db_host}}',
    'user': "{{db_username}}",
    'password': "{{db_password}}",
    'database': "{{db_database}}",
}

config['HMAC_ENCRYPTION_KEY'] = '{{hmac_key}}'
config['PSQL_USER_DB_CONNECTION'] = 'postgresql://{{userapi_username}}:{{userapi_password}}@{{userapi_host}}:5432/{{userapi_database}}'


config['OAUTH2'] = {
    'client_id': '{{oauth2_client_id}}',
    'client_secret': '{{oauth2_client_secret}}',
    'internal_oauth_provider': 'http://userapi-service.default/oauth2/',
    'oauth_provider': 'https://{{hostname}}/user/oauth2/', 
    'redirect_uri': 'https://{{hostname}}/api/v0/oauth2/authorize'
}
config['USER_API'] = 'http://userapi-service.default/'
app_init(app)
application = app
