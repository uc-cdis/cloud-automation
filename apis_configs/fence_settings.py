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

dir_path = os.path.dirname(os.path.realpath(__file__))
fence_creds = os.path.join(dir_path, 'fence_credentials.json')
if os.path.exists(fence_creds):
    with open(fence_creds, 'r') as f:
        data = json.load(f)
        AWS_CREDENTIALS = data['AWS_CREDENTIALS']
        S3_BUCKETS = data['S3_BUCKETS']
        DEFAULT_LOGIN_URL = data['DEFAULT_LOGIN_URL']
        OPENID_CONNECT.update(data['OPENID_CONNECT'])
        OIDC_ISSUER = data['OIDC_ISSUER']
        ENABLED_IDENTITY_PROVIDERS = data['ENABLED_IDENTITY_PROVIDERS']
        APP_NAME = data['APP_NAME']
        HTTP_PROXY = data['HTTP_PROXY']
        os.environ["GOOGLE_API_KEY"] = data['GOOGLE_API_KEY']
        os.environ["GOOGLE_PROJECT_ID"] = data['GOOGLE_PROJECT_ID']
        os.environ["GOOGLE_ADMIN_EMAIL"] = data['GOOGLE_ADMIN_EMAIL']
        os.environ["GOOGLE_IDENTITY_DOMAIN"] = data['GOOGLE_IDENTITY_DOMAIN']
        os.environ["GOOGLE_CLOUD_IDENTITY_ADMIN_EMAIL"] = (
            data['GOOGLE_CLOUD_IDENTITY_ADMIN_EMAIL']
        )

os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = (
    "/var/www/fence/google_secret.json"
)

DEFAULT_LOGIN_URL_REDIRECT_PARAM = 'redirect'

INDEXD = 'http://indexd-service.default/'
