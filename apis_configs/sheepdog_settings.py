from sheepdog.api import app, app_init
from os import environ

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
config['FLASK_SECRET_KEY'] = '{{gdcapi_secret_key}}'
config['PSQL_USER_DB_CONNECTION'] = 'postgresql://{{fence_username}}:{{fence_password}}@{{fence_host}}:5432/{{fence_database}}'


config['OAUTH2'] = {
    'client_id': '{{oauth2_client_id}}',
    'client_secret': '{{oauth2_client_secret}}',
    'internal_oauth_provider': 'http://fence-service.default/oauth2/',
    'oauth_provider': 'https://{{hostname}}/user/oauth2/', 
    'redirect_uri': 'https://{{hostname}}/api/v0/oauth2/authorize'
}
config['USER_API'] = 'http://fence-service.default/'
app_init(app)
application = app
