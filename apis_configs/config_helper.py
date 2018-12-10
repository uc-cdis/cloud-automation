import json
import os
import copy
import argparse
import re
import types

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
        "%s/gen3/%s" % (XDG_DATA_HOME, app_name),
        "/usr/share/gen3/%s" % app_name,
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
    indexd_password = _get_nested_value(creds, "indexd_password")
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

    print("  INDEXD_PASSWORD injected with value(s) from creds.json")
    config_file = _replace(config_file, "INDEXD_PASSWORD", indexd_password)
    config_file = _replace(config_file, "INDEXD_USERNAME", "fence")

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

    open(config_file_path, "w+").write(config_file)


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
    config_file = _replace(config_file, "DEBUG", False)

    print("  MOCK_AUTH set to false")
    config_file = _replace(config_file, "MOCK_AUTH", False)

    print("  MOCK_GOOGLE_AUTH set to false")
    config_file = _replace(config_file, "MOCK_GOOGLE_AUTH", False)

    print("  AUTHLIB_INSECURE_TRANSPORT set to true")
    config_file = _replace(config_file, "AUTHLIB_INSECURE_TRANSPORT", True)

    print("  SESSION_COOKIE_SECURE set to true")
    config_file = _replace(config_file, "SESSION_COOKIE_SECURE", True)

    print("  ENABLE_CSRF_PROTECTION set to true")
    config_file = _replace(config_file, "ENABLE_CSRF_PROTECTION", True)

    open(config_file_path, "w+").write(config_file)


def inject_other_files_into_fence_config(other_files, config_file_path):
    additional_cfgs = _get_all_additional_configs(other_files)

    config_file = open(config_file_path, "r").read()

    for key, value in additional_cfgs.iteritems():
        print("  {} set to {}".format(key, value))
        config_file = _nested_replace(config_file, key, value)

    open(config_file_path, "w+").write(config_file)


def _get_all_additional_configs(other_files):
    """
    Attempt to parse given list of files and extract configuration variables and values
    """
    additional_configs = dict()
    for file_path in other_files:
        try:
            file_ext = file_path.strip().split(".")[-1]
            if file_ext == "json":
                json_file = open(file_path, "r")
                configs = json.load(json_file)
                json_file.close()
            elif file_ext == "py":
                configs = from_pyfile(file_path)
            else:
                print(
                    "Cannot load config vars from a file with extention: {}".format(
                        file_ext
                    )
                )
        except Exception as exc:
            # if there's any issue reading the file, exit
            print(
                "Error reading {}. Cannot get configuration. Skipping this file. "
                "Details: {}".format(other_files, str(exc))
            )
            continue

        if configs:
            additional_configs.update(configs)

    return additional_configs


def _nested_replace(config_file, key, value, replacement_path=None):
    replacement_path = replacement_path or key
    try:
        for inner_key, inner_value in value.iteritems():
            temp_path = replacement_path
            temp_path = temp_path + "/" + inner_key
            config_file = _nested_replace(
                config_file, inner_key, inner_value, temp_path
            )
    except AttributeError:
        # not a dict so replace
        if value is not None:
            config_file = _replace(config_file, replacement_path, value)

    return config_file


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
    search_string = (
        "  " * nested_level + ".*" + nested_path_to_replace[0] + "(')?(\")?:.*\n"
    )
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
                _get_yaml_replacement_value(replacement_value, nested_level),
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


def from_pyfile(filename, silent=False):
    """
    Modeled after flask's ability to load in python files:
    https://github.com/pallets/flask/blob/master/flask/config.py

    Some alterations were made but logic is essentially the same
    """
    filename = os.path.abspath(filename)
    d = types.ModuleType("config")
    d.__file__ = filename
    try:
        with open(filename, mode="rb") as config_file:
            exec(compile(config_file.read(), filename, "exec"), d.__dict__)
    except IOError as e:
        print("Unable to load configuration file ({})".format(e.strerror))
        if silent:
            return False
        raise
    return _from_object(d)


def _from_object(obj):
    configs = {}
    for key in dir(obj):
        if key.isupper():
            configs[key] = getattr(obj, key)
    return configs


def _get_yaml_replacement_value(value, nested_level=0):
    if isinstance(value, str):
        return "'" + value + "'"
    elif isinstance(value, bool):
        return str(value).lower()
    elif isinstance(value, list) or isinstance(value, set):
        output = ""
        for item in value:
            # spaces for nested level then spaces and hyphen for each list item
            output += (
                "\n"
                + "  " * nested_level
                + "  - "
                + _get_yaml_replacement_value(item)
                + ""
            )
        return output
    else:
        return value


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
        "--other_files_to_inject",
        nargs="+",
        help="fence_credentials.json, local_settings.py, fence_settings.py file(s) to "
        "inject into the configuration yaml",
    )
    parser.add_argument(
        "-c", "--config_file", default="config.yaml", help="configuration yaml"
    )
    args = parser.parse_args()

    inject_creds_into_fence_config(args.creds_file_to_inject, args.config_file)
    set_prod_defaults(args.config_file)

    if args.other_files_to_inject:
        inject_other_files_into_fence_config(
            args.other_files_to_inject, args.config_file
        )
