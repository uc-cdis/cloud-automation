import json
import os
import argparse
import re
import types
import yaml
from enum import Enum

class ConfigAction(Enum):
    REPLACE = 1
    DELETE = 2

def modify_config_from_files(file_path, config_file_path, action):
    configs_to_add = _load_config_file(file_path)
    config_str = open(config_file_path, "r").read()
    for key, value in configs_to_add.items():
        config_str = _nested_modify_config(action, config_str, key, value)
    return config_str


def extract_config_from_files(template_file_path, config_file_path):
    template_config = _load_config_file(template_file_path)
    config = _load_config_file(config_file_path)
    result_content = {}
    for template_key, template_value in template_config.items():
        if config is not None and template_key in config and config[template_key] is not None:
            result_content[template_key] = _nested_extract_config(template_value, config[template_key])
    result_json_str = json.dumps(result_content, indent=4)
    return result_json_str


def _nested_extract_config(template, source):
    """
    Deep extract configuration from source config using template config. 

    Args:
        template: template config structure to extract
        source: config structure to extract from

    Example:
        template: {
            'a': "xxx",
            'b': {
                'd': "yyy"
            },
            'e': "zzz",
            'f': "www"
        }
        source: {
            'a': 1,
            'b': {
                'c': 2, 
                'd': {
                    'g': 3
                }
            }, 
            'e': 4
        }
        return: {
            'a': 1, 
            'b': {
                'd': {
                    'g': 3
                }
            }, 
            'e': 4
        }
    """
    result_content = {}
    try:
        for inner_key, inner_value in template.items():
            if source is not None and inner_key in source and source[inner_key] is not None:
                child_result = _nested_extract_config(template[inner_key], source[inner_key])
                result_content[inner_key] = child_result
    except AttributeError:
        # not a dict so replace
        if template is not None:
            result_content = source
            
    return result_content

def _load_config_file(file_path): 
    configs = None
    try:
        file_ext = file_path.strip().split(".")[-1]
        if file_ext == "json":
            json_file = open(file_path, "r")
            configs = json.load(json_file)
            json_file.close()
        elif file_ext == 'yaml':
            yaml_file = open(file_path, "r")
            configs = yaml.safe_load(yaml_file)
            yaml_file.close()
        else:
            print((
                "Cannot load config vars from a file with extention: {}".format(
                    file_ext
                )
            ))
    except Exception as exc:
        # if there's any issue reading the file, exit
        print((
            "Error reading {}. Cannot get configuration. Skipping this file. "
            "Details: {}".format(file_list, str(exc))
        ))
        raise

    return configs


def _get_all_configs(file_list):
    """
    Attempt to parse given list of files and extract configuration variables and values
    """
    additional_configs = dict()
    for file_path in file_list:
        configs = _load_config_file(file_path)
        if configs:
            additional_configs.update(configs)

    return additional_configs


def _nested_modify_config(action, config_str, key, value, traverse_path=None):
    traverse_path = traverse_path or key
    try:
        for inner_key, inner_value in value.items():
            temp_path = traverse_path
            temp_path = temp_path + "/" + inner_key
            config_str = _nested_modify_config(
                action, config_str, inner_key, inner_value, temp_path
            )
    except AttributeError:
        # not a dict so replace
        if value is not None:
            config_str = _modify_config(action, config_str, traverse_path, value)
            
    return config_str


def _find_next_sibling_or_parent_position(yaml_config_str, start, nested_level):
    """
    Find the position of the next non-child configuration in a YAML file string.
    Assume comments are always above the configurations.

    Args:
        yaml_config_str (str): a string representing a full configuration file
        start (integer): start position fo the key
        nested_level (integer): nested level count
    """
    lines = yaml_config_str[start:].split("\n")
    last_end_position = start
    last_child_end_position = start
    for line in lines:
        line_without_leading_spaces = line.lstrip(' ')
        is_comment = (len(line_without_leading_spaces) > 0 and line_without_leading_spaces[0] == "#")
        leading_spaces_cnt = len(line) - len(line.lstrip(' '))
        is_child = (leading_spaces_cnt > nested_level * 2)
        is_empty_line = (len(line_without_leading_spaces) == 0)
        if not (is_empty_line or is_comment or is_child):
            break
        else:
            last_end_position += len(line) + 1 # plus one because "\n"
            if is_child:
                last_child_end_position = last_end_position
    return last_child_end_position


def _find_comments_start_position(yaml_config_str, pos):
    """
    Find the start position of the comment block in a YAML file string.
    Assume comments are always above the configurations.

    Args:
        yaml_config_str (str): a string representing a full configuration file
        pos (integer): position of the key
    """
    # get all previous lines
    lines = yaml_config_str[:pos].split("\n")
    # last charactor is \n then the last item is emtpy, remove it
    if len(lines[-1]) == 0:
        del lines[-1]
    comments_start_pos = pos;
    for line in lines[::-1]:
        line_without_leading_spaces = line.lstrip(' ')
        is_comment = (len(line_without_leading_spaces) > 0 and line_without_leading_spaces[0] == "#")
        if is_comment:
            comments_start_pos -= (len(line) + 1)
        else:
            break
    return comments_start_pos


def _modify_config(action, yaml_config_str, path_to_key, replacement_value, start=0, nested_level=0):
    """
    A recursive function that replaces/deletes a nested value in a YAML file string with
    the given value without losing comments. Uses a regex to do the replacement/deletion.

    Args:
        action (ConfigAction): DELETE, or REPLACE
        yaml_config_str (str): a string representing a full configuration file
        path_to_key (str): nested/path/to/key. The value of this key will be
            replaced
        replacement_value (str): Replacement value for the key from
            path_to_key
    """
    nested_path = path_to_key.split("/")

    # our regex looks for a specific number of spaces to ensure correct
    # level of nesting. It matches to the end of the line
    # The regex should also matche commented line, assuming the line starts with a hash,
    # and commented contents are still correctly indented
    search_string = (
        "(#|# )?" + "  " * nested_level + "(\'|\")?" + nested_path[0] + "(\'|\")?:.*(\n|$)"
    )
    matches = re.search(search_string, yaml_config_str[start:])

    # early return if we haven't found anything
    if not matches:
        return yaml_config_str

    match_start = start + matches.start(0)
    match_end = start + matches.end(0)

    # if we're on the last item in the path, we need to get the value and
    # replace it in the original file
    if len(nested_path) == 1:
        # should ignore all children, find next starting position
        next_starting_position = _find_next_sibling_or_parent_position(yaml_config_str, match_end, nested_level);

        if action == ConfigAction.REPLACE:
            yaml_config_str = (
                yaml_config_str[:match_start]
                + "  " * nested_level + "{}: {}\n".format(
                    nested_path[0],
                    _get_yaml_replacement_value(replacement_value, nested_level),
                )
                + yaml_config_str[next_starting_position:]
            )
        elif action == ConfigAction.DELETE:
            # should ignore the comments for this matched key
            comments_starting_position = _find_comments_start_position(yaml_config_str, match_start);
            yaml_config_str = (
                yaml_config_str[:comments_starting_position]
                + yaml_config_str[next_starting_position:]
            )
        return yaml_config_str

    # set new start point to past current match and move on to next match
    start += matches.end(0)

    replaced_result = _modify_config(
        action,
        yaml_config_str,
        "/".join(nested_path[1:]),
        replacement_value,
        start,
        nested_level + 1,
    )
    if action == ConfigAction.REPLACE:
        if yaml_config_str[match_start] == '#':
            replaced_result = (
                replaced_result[0:match_start] + nested_level * '  '
                + nested_path[0] + ':\n'
                + replaced_result[match_end:]
            )
    return replaced_result


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


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Fence config helper")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "-r",
        "--file_to_replace",
        help="A config files (.json, .yaml) to replace into the configuration yaml, output is in yaml format",
    )
    group.add_argument(
        "-d",
        "--file_to_delete",
        help="A config files (.json, .yaml) to remove from the configuration yaml, output is in yaml format",
    )
    group.add_argument(
        "-e",
        "--template_file",
        help="A config template (.json, .yaml) to extract from the configuration yaml, output is in JSON format",
    )
    parser.add_argument(
        "-c", "--config_file", default="config.yaml", help="configuration yaml"
    )
    args = parser.parse_args()

    # these three options (-r, -d, -e) are mutually exclusive
    if args.file_to_replace:
        print(modify_config_from_files(args.file_to_replace, args.config_file, ConfigAction.REPLACE))
    if args.file_to_delete:
        print(modify_config_from_files(args.file_to_delete, args.config_file, ConfigAction.DELETE))
    if args.template_file:
        print(extract_config_from_files(args.template_file, args.config_file))
