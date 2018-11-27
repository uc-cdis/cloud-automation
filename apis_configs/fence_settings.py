from boto.s3.connection import OrdinaryCallingFormat
import config_helper

APP_NAME = "fence"

DB = "postgresql://{{db_username}}:{{db_password}}@{{db_host}}:5432/{{db_database}}"

MOCK_AUTH = False
MOCK_STORAGE = True

EMAIL_SERVER = "localhost"

SEND_FROM = "phillis.tt@gmail.com"

SEND_TO = "phillis.tt@gmail.com"

CEPH = {
    "aws_access_key_id": "",
    "aws_secret_access_key": "",
    "host": "",
    "port": 443,
    "is_secure": True,
    "calling_format": OrdinaryCallingFormat(),
}

AWS = {"aws_access_key_id": "", "aws_secret_access_key": ""}

HMAC_ENCRYPTION_KEY = "{{hmac_key}}"


HOSTNAME = "{{hostname}}"
BASE_URL = "https://{{hostname}}/user"

OPENID_CONNECT = {
    "google": {
        "client_id": "{{google_client_id}}",
        "client_secret": "{{google_client_secret}}",
        "redirect_url": "https://" + HOSTNAME + "/user/login/google/login/",
    }
}

HTTP_PROXY = {"host": "cloud-proxy.internal.io", "port": 3128}

DEFAULT_DBGAP = {
    "sftp": {
        "host": "",
        "username": "",
        "password": "",
        "port": 22,
        "proxy": "",
        "proxy_user": "",
    },
    "decrypt_key": "",
}

STORAGE_CREDENTIALS = {}
# aws_credentials should be a dict looks like:
# { identifier: { 'aws_access_key_id': 'XXX', 'aws_secret_access_key': 'XXX' }}
AWS_CREDENTIALS = {}

# s3_buckets should be a dict looks like:
# { bucket_name: credential_identifie }
S3_BUCKETS = {}


def load_json(file_name):
    return config_helper.load_json(file_name, APP_NAME)


def get_from_dict(dictionary, key, default=""):
    value = dictionary.get(key)
    if value is None:
        value = default
    return value


creds = load_json("creds.json")
key_list = ["db_username", "db_password", "db_host", "db_database"]

DB = "postgresql://%s:%s@%s:5432/%s" % tuple(
    [get_from_dict(creds, k, "unknown-" + k) for k in key_list]
)
HMAC_ENCRYPTION_KEY = get_from_dict(creds, "hmac_key", "unknown-hmac_key")
HOSTNAME = get_from_dict(creds, "hostname", "unknown-hostname")
BASE_URL = "https://%s/user" % HOSTNAME

OPENID_CONNECT["google"]["client_id"] = get_from_dict(
    creds, "google_client_id", "unknown-google_client_id"
)
OPENID_CONNECT["google"]["client_secret"] = get_from_dict(
    creds, "google_client_secret", "unknown-google_client_secret"
)
OPENID_CONNECT["google"]["redirect_url"] = (
    "https://" + HOSTNAME + "/user/login/google/login/"
)

GOOGLE_MANAGED_SERVICE_ACCOUNT_DOMAINS = {
    "dataflow-service-producer-prod.iam.gserviceaccount.com",
    "cloudbuild.gserviceaccount.com",
    "cloud-ml.google.com.iam.gserviceaccount.com",
    "container-engine-robot.iam.gserviceaccount.com",
    "dataflow-service-producer-prod.iam.gserviceaccount.com",
    "sourcerepo-service-accounts.iam.gserviceaccount.com",
    "dataproc-accounts.iam.gserviceaccount.com",
    "gae-api-prod.google.com.iam.gserviceaccount.com",
    "genomics-api.google.com.iam.gserviceaccount.com",
    "containerregistry.iam.gserviceaccount.com",
    "container-analysis.iam.gserviceaccount.com",
    "cloudservices.gserviceaccount.com",
    "stackdriver-service.iam.gserviceaccount.com",
    "appspot.gserviceaccount.com",
    "partnercontent.gserviceaccount.com",
    "trifacta-gcloud-prod.iam.gserviceaccount.com",
    "gcf-admin-robot.iam.gserviceaccount.com",
    "compute-system.iam.gserviceaccount.com",
    "gcp-sa-websecurityscanner.iam.gserviceaccount.com",
    "storage-transfer-service.iam.gserviceaccount.com",
}

CIRRUS_CFG = {}
data = load_json("fence_credentials.json")
if data:
    AWS_CREDENTIALS = data["AWS_CREDENTIALS"]
    S3_BUCKETS = data["S3_BUCKETS"]
    DEFAULT_LOGIN_URL = data["DEFAULT_LOGIN_URL"]
    OPENID_CONNECT.update(data["OPENID_CONNECT"])
    OIDC_ISSUER = data["OIDC_ISSUER"]
    ENABLED_IDENTITY_PROVIDERS = data["ENABLED_IDENTITY_PROVIDERS"]
    APP_NAME = data["APP_NAME"]
    HTTP_PROXY = data["HTTP_PROXY"]
    dbGaP = data.get("dbGaP", DEFAULT_DBGAP)
    CIRRUS_CFG["GOOGLE_API_KEY"] = get_from_dict(data, "GOOGLE_API_KEY")
    CIRRUS_CFG["GOOGLE_PROJECT_ID"] = get_from_dict(data, "GOOGLE_PROJECT_ID")
    CIRRUS_CFG["GOOGLE_ADMIN_EMAIL"] = get_from_dict(data, "GOOGLE_ADMIN_EMAIL")
    CIRRUS_CFG["GOOGLE_IDENTITY_DOMAIN"] = get_from_dict(data, "GOOGLE_IDENTITY_DOMAIN")
    CIRRUS_CFG["GOOGLE_CLOUD_IDENTITY_ADMIN_EMAIL"] = get_from_dict(
        data, "GOOGLE_CLOUD_IDENTITY_ADMIN_EMAIL"
    )

    STORAGE_CREDENTIALS = get_from_dict(data, "STORAGE_CREDENTIALS", {})
    GOOGLE_GROUP_PREFIX = get_from_dict(data, "GOOGLE_GROUP_PREFIX", "gen3")
    SUPPORT_EMAIL_FOR_ERRORS = get_from_dict(data, "SUPPORT_EMAIL_FOR_ERRORS", None)
    WHITE_LISTED_SERVICE_ACCOUNT_EMAILS = get_from_dict(
        data, "WHITE_LISTED_SERVICE_ACCOUNT_EMAILS", []
    )
    WHITE_LISTED_GOOGLE_PARENT_ORGS = get_from_dict(
        data, "WHITE_LISTED_GOOGLE_PARENT_ORGS", []
    )
    GOOGLE_MANAGED_SERVICE_ACCOUNT_DOMAINS.update(
        data.get("GOOGLE_MANAGED_SERVICE_ACCOUNT_DOMAINS", [])
    )
    GUN_MAIL = data.get("GUN_MAIL")
    REMOVE_SERVICE_ACCOUNT_EMAIL_NOTIFICATION = data.get(
        "REMOVE_SERVICE_ACCOUNT_EMAIL_NOTIFICATION"
    )
    # use for intergration tests to skip the login page
    MOCK_GOOGLE_AUTH = data.get("MOCK_GOOGLE_AUTH", False)

CIRRUS_CFG[
    "GOOGLE_APPLICATION_CREDENTIALS"
] = "/var/www/fence/fence_google_app_creds_secret.json"
CIRRUS_CFG[
    "GOOGLE_STORAGE_CREDS"
] = "/var/www/fence/fence_google_storage_creds_secret.json"

DEFAULT_LOGIN_URL_REDIRECT_PARAM = "redirect"

INDEXD = "http://indexd-service/"

ARBORIST = "http://arborist-service/"
