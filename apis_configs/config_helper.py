import json
import os
import copy
import argparse
import re

#
# make it easy to change this for testing
XDG_DATA_HOME = os.getenv("XDG_DATA_HOME", "/usr/share/")


def default_search_folders(app_name):
    """
    Return the list of folders to search for configuration files
    """
    return [
        "%s/cdis/%s" % (XDG_DATA_HOME, app_name),
        "/usr/share/cdis/%s" % app_name,
        "/var/www/%s" % app_name,
        "/etc/gen3/%s" % app_name,
    ]


def find_paths(file_name, app_name, search_folders=None):
    """
    Search the given folders for file_name
    search_folders defaults to default_search_folders if not specified
    return the first path to file_name found
    """
    search_folders = search_folders or default_search_folders(app_name)
    possible_files = [os.path.join(folder, file_name) for folder in search_folders]
    return [path for path in possible_files if os.path.exists(path)]


def load_json(file_name, app_name, search_folders=None):
    """
    json.load(file_name) after finding file_name in search_folders

    return the loaded json data or None if file not found
    """
    actual_files = find_paths(file_name, app_name, search_folders)
    if not actual_files:
        return None
    with open(actual_files[0], "r") as reader:
        return json.load(reader)


def inject_creds_into_fence_config(creds_file_path, config_file_path):
    creds_file = open(creds_file_path, "r")
    creds = json.load(creds_file)
    creds_file.close()

    # get secret values from creds.json file
    db_host = _get_nested_value(creds, "db_host")
    db_username = _get_nested_value(creds, "db_username")
    db_password = _get_nested_value(creds, "db_password")
    db_database = _get_nested_value(creds, "db_database")
    hostname = _get_nested_value(creds, "hostname")
    google_client_secret = _get_nested_value(creds, "google_client_secret")
    google_client_id = _get_nested_value(creds, "google_client_id")
    hmac_key = _get_nested_value(creds, "hmac_key")
    db_path = "postgresql://{}:{}@{}:5432/{}".format(
        db_username, db_password, db_host, db_database
    )

    config_file = open(config_file_path, "r").read()

    print("  DB injected with value(s) from creds.json")
    config_file = _replace(config_file, "DB", db_path)

    print("  BASE_URL injected with value(s) from creds.json")
    config_file = _replace(config_file, "BASE_URL", "https://{}/user".format(hostname))

    print("  ENCRYPTION_KEY injected with value(s) from creds.json")
    config_file = _replace(config_file, "ENCRYPTION_KEY", hmac_key)

    print(
        "  OPENID_CONNECT/google/client_secret injected with value(s) "
        "from creds.json"
    )
    config_file = _replace(
        config_file, "OPENID_CONNECT/google/client_secret", google_client_secret
    )

    print("  OPENID_CONNECT/google/client_id injected with value(s) from creds.json")
    config_file = _replace(
        config_file, "OPENID_CONNECT/google/client_id", google_client_id
    )

    open(config_file_path, "w").write(config_file)


def set_prod_defaults(config_file_path):
    config_file = open(config_file_path, "r").read()

    print(
        "  CIRRUS_CFG/GOOGLE_APPLICATION_CREDENTIALS set as "
        "var/www/fence/fence_google_app_creds_secret.json"
    )
    config_file = _replace(
        config_file,
        "CIRRUS_CFG/GOOGLE_APPLICATION_CREDENTIALS",
        "/var/www/fence/fence_google_app_creds_secret.json",
    )

    print(
        "  CIRRUS_CFG/GOOGLE_STORAGE_CREDS set as "
        "var/www/fence/fence_google_storage_creds_secret.json"
    )
    config_file = _replace(
        config_file,
        "CIRRUS_CFG/GOOGLE_STORAGE_CREDS",
        "/var/www/fence/fence_google_storage_creds_secret.json",
    )

    print("  INDEXD set as http://indexd-service/")
    config_file = _replace(config_file, "INDEXD", "http://indexd-service/")

    print("  ARBORIST set as http://arborist-service/")
    config_file = _replace(config_file, "ARBORIST", "http://arborist-service/")

    print("  HTTP_PROXY/host set as cloud-proxy.internal.io")
    config_file = _replace(config_file, "HTTP_PROXY/host", "cloud-proxy.internal.io")

    print("  HTTP_PROXY/port set as 3128")
    config_file = _replace(config_file, "HTTP_PROXY/port", 3128)

    print("  DEBUG set to false")
    config_file = _replace(config_file, "DEBUG", "false")

    print("  MOCK_AUTH set to false")
    config_file = _replace(config_file, "MOCK_AUTH", "false")

    print("  MOCK_GOOGLE_AUTH set to false")
    config_file = _replace(config_file, "MOCK_GOOGLE_AUTH", "false")

    print("  AUTHLIB_INSECURE_TRANSPORT set to false")
    config_file = _replace(config_file, "AUTHLIB_INSECURE_TRANSPORT", "false")

    print("  SESSION_COOKIE_SECURE set to true")
    config_file = _replace(config_file, "SESSION_COOKIE_SECURE", "true")

    print("  ENABLE_CSRF_PROTECTION set to true")
    config_file = _replace(config_file, "ENABLE_CSRF_PROTECTION", "true")

    open(config_file_path, "w").write(config_file)


def _replace(yaml_config, path_to_key, replacement_value, start=0, nested_level=0):
    """
    Replace a nested value in a YAML file string with the given value without
    losing comments. Uses a regex to do the replacement.

    Args:
        yaml_config (str): a string representing a full configuration file
        path_to_key (str): nested/path/to/key. The value of this key will be
            replaced
        replacement_value (str): Replacement value for the key from
            path_to_key
    """
    nested_path_to_replace = path_to_key.split("/")

    # our regex looks for a specific number of spaces to ensure correct
    # level of nesting. It matches to the end of the line
    search_string = "  " * nested_level + ".*" + nested_path_to_replace[0] + ":.*\n"
    matches = re.search(search_string, yaml_config[start:])

    # early return if we haven't found anything
    if not matches:
        return yaml_config

    # if we're on the last item in the path, we need to get the value and
    # replace it in the original file
    if len(nested_path_to_replace) == 1:
        # replace the current key:value with the new replacement value
        match_start = start + matches.start(0) + len("  " * nested_level)
        match_end = start + matches.end(0)
        yaml_config = (
            yaml_config[:match_start]
            + "{}: {}\n".format(
                nested_path_to_replace[0],
                _get_yaml_replacement_value(replacement_value),
            )
            + yaml_config[match_end:]
        )

        return yaml_config

    # set new start point to past current match and move on to next match
    start = matches.end(0)
    nested_level += 1
    del nested_path_to_replace[0]

    return _replace(
        yaml_config,
        "/".join(nested_path_to_replace),
        replacement_value,
        start,
        nested_level,
    )


def _get_yaml_replacement_value(value):
    if isinstance(value, str):
        return "'" + value + "'"
    elif isinstance(value, bool):
        return str(value).lower()


def _get_nested_value(dictionary, nested_path):
    """
    Return a value from a dictionary given a path-like nesting of keys.

    Will default to an empty string if value cannot be found.

    Args:
        dictionary (dict): a dictionary
        nested_path (str): nested/path/to/key

    Returns:
        ?: Value from dict
    """
    replacement_value_path = nested_path.split("/")
    replacement_value = copy.deepcopy(dictionary)

    for item in replacement_value_path:
        replacement_value = replacement_value.get(item, {})

    if replacement_value == {}:
        replacement_value = ""

    return replacement_value


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-i",
        "--creds_file_to_inject",
        default="creds.json",
        help="creds file to inject into the configuration yaml",
    )
    parser.add_argument(
        "-c", "--config_file", default="config.yaml", help="configuration yaml"
    )

    args = parser.parse_args()

    inject_creds_into_fence_config(args.creds_file_to_inject, args.config_file)
    set_prod_defaults(args.config_file)
