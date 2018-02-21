from boto.s3.connection import OrdinaryCallingFormat
import json
import os


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
STORAGE_CREDENTIALS = {}
# aws_credentials should be a dict looks like:
# { identifier: { 'aws_access_key_id': 'XXX', 'aws_secret_access_key': 'XXX' }}
AWS_CREDENTIALS = {}

# s3_buckets should be a dict looks like:
# { bucket_name: credential_identifie }
S3_BUCKETS = {}

if os.path.exists('s3_credentials.json'):
    with open('s3_credentials.json', 'r') as f:
        data = json.load(f)
        AWS_CREDENTIALS = data['AWS_CREDENTIALS']
        S3_BUCKETS = data['S3_BUCKETS']
        DEFAULT_LOGIN_URL = data['DEFAULT_LOGIN_URL']
        OPENID_CONNECT.update(data['OPENID_CONNECT'])

DEFAULT_LOGIN_URL_REDIRECT_PARAM = 'redirect'

INDEXD = 'http://indexd-service.default/'
