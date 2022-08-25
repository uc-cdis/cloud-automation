{
    "fence": {
        "db_host": "${fence_host}",
        "db_username": "${fence_user}",
        "db_password": "${fence_pwd}",
        "db_database": "${fence_db}",
        "hostname": "${hostname}",
        "indexd_password": "",
        "google_client_secret": "${google_client_secret}",
        "google_client_id": "${google_client_id}",
        "hmac_key": "${hmac_encryption_key}"
    },
    "sheepdog": {
        "fence_host": "${fence_host}",
        "fence_username": "${fence_user}",
        "fence_password": "${fence_pwd}",
        "fence_database": "${fence_db}",
        "db_host": "${sheepdog_host}",
        "db_username": "${sheepdog_user}",
        "db_password": "${sheepdog_pwd}",
        "db_database": "${sheepdog_db}",
        "gdcapi_secret_key": "${sheepdog_secret_key}",
        "indexd_password": "${sheepdog_indexd_password}",
        "hostname": "${hostname}",
        "oauth2_client_id": "${sheepdog_oauth2_client_id}",
        "oauth2_client_secret": "${sheepdog_oauth2_client_secret}"
    },
    "peregrine": {
        "fence_host": "${fence_host}",
        "fence_username": "${fence_user}",
        "fence_password": "${fence_pwd}",
        "fence_database": "${fence_db}",
        "db_host": "${peregrine_host}",
        "db_username": "peregrine",
        "db_password": "${peregrine_pwd}",
        "db_database": "${sheepdog_db}",
        "gdcapi_secret_key": "${sheepdog_secret_key}",
        "hostname": "${hostname}"
    },
    "indexd": {
        "db_host": "${indexd_host}",
        "db_username": "${indexd_user}",
        "db_password": "${indexd_pwd}",
        "db_database": "${indexd_db}",
        "index_config": {
          "DEFAULT_PREFIX": "${indexd_prefix}",
          "PREPEND_PREFIX": true
        },
        "user_db": {
          "gdcapi": "${sheepdog_indexd_password}",
          "fence": ""
        }
    },
    "es": {
        "aws_access_key_id": "${aws_user_key_id}",
        "aws_secret_access_key": "${aws_user_key}"
    },
    "mailgun": {
        "mailgun_api_key": "${mailgun_api_key}",
        "mailgun_api_url": "${mailgun_api_url}",
        "mailgun_smtp_host": "${mailgun_smtp_host}"
    }
}
