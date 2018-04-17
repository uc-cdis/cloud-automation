from boto.s3.connection import OrdinaryCallingFormat
import json
import os
import config_helper

APP_NAME='fence'
def load_json(file_name):
  return config_helper.load_json(file_name, APP_NAME)

DB = 'postgresql://{{db_username}}:{{db_password}}@{{db_host}}:5432/{{db_database}}'

MOCK_AUTH = False
MOCK_STORAGE = True

EMAIL_SERVER = 'localhost'

SEND_FROM = 'phillis.tt@gmail.com'

SEND_TO = 'phillis.tt@gmail.com'

CEPH = {
    'aws_access_key_id': '',
    'aws_secret_access_key': '',
    'host': '',
    'port': 443,
    'is_secure': True,
    "calling_format": OrdinaryCallingFormat()
}

AWS = {
    'aws_access_key_id': '',
    'aws_secret_access_key': '',
}

HMAC_ENCRYPTION_KEY = '{{hmac_key}}'


HOSTNAME = '{{hostname}}'
BASE_URL = 'https://{{hostname}}/user'

OPENID_CONNECT = {
    'google': {
        'client_id': '{{google_client_id}}',
        'client_secret': '{{google_client_secret}}',
        'redirect_url': 'https://' + HOSTNAME + '/user/login/google/login/',
    }
}

HTTP_PROXY = {
    'host': 'cloud-proxy.internal.io',
    'port': 3128
}

DEFAULT_DBGAP = {
    'sftp': {'host': '',
             'username': '',
             'password': '',
             'port': 22,
             'proxy': '',
             'proxy_user': '',
             },
    'decrypt_key': ''}

STORAGE_CREDENTIALS = {}
# aws_credentials should be a dict looks like:
# { identifier: { 'aws_access_key_id': 'XXX', 'aws_secret_access_key': 'XXX' }}
AWS_CREDENTIALS = {}

# s3_buckets should be a dict looks like:
# { bucket_name: credential_identifie }
S3_BUCKETS = {}

creds = load_json('creds.json')
key_list = [ 'db_username', 'db_password', 'db_host', 'db_database' ]
DB = 'postgresql://%s:%s@%s:5432/%s' % tuple([ creds.get(k,'unknown-'+k) for k in key_list ])
HMAC_ENCRYPTION_KEY = creds.get('hmac_key', 'unknown-hmac_key')
HOSTNAME = creds.get('hostname', 'unknown-hostname')
BASE_URL = 'https://%s/user' % HOSTNAME
OPENID_CONNECT['google']['client_id'] = creds.get('google_client_id', 'unknown-google_client_id') 
OPENID_CONNECT['google']['client_secret'] = creds.get('google_client_secret', 'unknown-google_client_secret') 
OPENID_CONNECT['google']['redirect_url'] = 'https://' + HOSTNAME + '/user/login/google/login/'

data = load_json('fence_credentials.json')
if data:
  AWS_CREDENTIALS = data['AWS_CREDENTIALS']
  S3_BUCKETS = data['S3_BUCKETS']
  DEFAULT_LOGIN_URL = data['DEFAULT_LOGIN_URL']
  OPENID_CONNECT.update(data['OPENID_CONNECT'])
  OIDC_ISSUER = data['OIDC_ISSUER']
  ENABLED_IDENTITY_PROVIDERS = data['ENABLED_IDENTITY_PROVIDERS']
  APP_NAME = data['APP_NAME']
  HTTP_PROXY = data['HTTP_PROXY']
  dbGaP = data.get('dbGaP',DEFAULT_DBGAP)
  

DEFAULT_LOGIN_URL_REDIRECT_PARAM = 'redirect'

INDEXD = 'http://indexd-service.default/'
