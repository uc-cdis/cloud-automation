import json
import os
import yaml
import copy
import argparse

# make it easy to change this for testing
XDG_DATA_HOME = os.getenv('XDG_DATA_HOME', '/usr/share/')


def default_search_folders(app_name):
    """
    Return the list of folders to search for configuration files
    """
    return [
      '%s/cdis/%s' % (XDG_DATA_HOME, app_name),
      '/usr/share/cdis/%s' % app_name,
      '/var/www/%s' % app_name,
      '/etc/gen3/%s' % app_name
    ]


def find_paths(file_name, app_name, search_folders=None):
    """
    Search the given folders for file_name
    search_folders defaults to default_search_folders if not specified
    return the first path to file_name found
    """
    search_folders = search_folders or default_search_folders(app_name)
    possible_files = [
        os.path.join(folder, file_name)
        for folder in search_folders
    ]
    return [path for path in possible_files if os.path.exists(path)]


def load_json(file_name, app_name, search_folders=None):
    """
    json.load(file_name) after finding file_name in search_folders

    return the loaded json data or None if file not found
    """
    actual_files = find_paths(file_name, app_name, search_folders)
    if not actual_files:
        return None
    with open(actual_files[0], 'r') as reader:
        return json.load(reader)


def inject_creds_into_fence_config(creds_file_path, config_file_path):
    creds_file = open(creds_file_path, 'r')
    config_file = open(config_file_path, 'r')

    creds = json.load(creds_file)
    config = yaml.safe_load(config_file)

    creds_file.close()
    config_file.close()

    # get secret values from creds.json file
    db_host = _get_nested_value(creds, 'db_host')
    db_username = _get_nested_value(creds, 'db_username')
    db_password = _get_nested_value(creds, 'db_password')
    db_database = _get_nested_value(creds, 'db_database')
    hostname = _get_nested_value(creds, 'hostname')
    google_client_secret = _get_nested_value(creds, 'google_client_secret')
    google_client_id = _get_nested_value(creds, 'google_client_id')
    hmac_key = _get_nested_value(creds, 'hmac_key')

    # inject creds.json values into yaml configuration for fence
    db_path = (
        'postgresql://{}:{}@{}:5432/{}'
        .format(db_host, db_username, db_password, db_database)
    )
    _replace(config, 'DB', db_path)
    _replace(config, 'BASE_URL', 'https://{}/user'.format(hostname))
    _replace(config, 'ENCRYPTION_KEY', hmac_key)
    _replace(
        config, 'OPENID_CONNECT/google/client_secret', google_client_secret)
    _replace(config, 'OPENID_CONNECT/google/client_id', google_client_id)
    _replace(
        config, 'CIRRUS_CFG/GOOGLE_APPLICATION_CREDENTIALS',
        '/var/www/fence/fence_google_app_creds_secret.json')
    _replace(
        config, 'CIRRUS_CFG/GOOGLE_STORAGE_CREDS',
        '/var/www/fence/fence_google_storage_creds_secret.json')

    with open(config_file_path, 'w') as config_file:
        yaml.safe_dump(config, config_file, allow_unicode=True, default_flow_style=False)


def _replace(data, path_to_key, replacement_value):
    """
    With replace a nested value in a dict with the given value.

    Args:
        data (dict): a dictionary
        path_to_key (str): nested/path/to/key. The value of this key will be
            replaced
        replacement_value (str): Replacement value for the key from
            path_to_key
    """
    nested_path_to_replace = path_to_key.split('/')

    # reconstruct the dict with new value
    for item in nested_path_to_replace[:-1]:
        data = data.get(item, {})

    data.update(
        {str(nested_path_to_replace[-1]): replacement_value}
    )


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
    replacement_value_path = nested_path.split('/')
    replacement_value = copy.deepcopy(dictionary)

    for item in replacement_value_path:
        replacement_value = replacement_value.get(item, {})

    if replacement_value == {}:
        replacement_value = ''

    return replacement_value


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-i', '--creds_file_to_inject', default='creds.json',
        help='creds file to inject into the configuration yaml')
    parser.add_argument(
        '-c', '--config_file', default='config.yaml',
        help='configuration yaml')

    args = parser.parse_args()

    inject_creds_into_fence_config(
        args.creds_file_to_inject,
        args.config_file
    )
