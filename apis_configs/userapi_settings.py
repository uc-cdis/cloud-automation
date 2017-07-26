from boto.s3.connection import OrdinaryCallingFormat
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
