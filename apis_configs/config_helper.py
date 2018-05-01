import json
import os

# make it easy to change this for testing
XDG_DATA_HOME=os.getenv('XDG_DATA_HOME','/usr/share/')

def default_search_folders(app_name): 
  '''
  Return the list of folders to search for configuration files
  '''
  return [
    '%s/cdis/%s' % (XDG_DATA_HOME, app_name),
    '/usr/share/cdis/%s' % app_name,
    '/var/www/%s' % app_name
  ]

def find_paths(file_name,app_name,search_folders=None):
  '''
  Search the given folders for file_name
  search_folders defaults to default_search_folders if not specified
  return the first path to file_name found
  '''
  search_folders = search_folders or default_search_folders(app_name)
  possible_files = [ os.path.join(folder, file_name) for folder in search_folders ]
  return [ path for path in possible_files if os.path.exists(path) ]

def load_json(file_name,app_name,search_folders=None):
  '''
  json.load(file_name) after finding file_name in search_folders

  return the loaded json data or None if file not found
  '''
  actual_files = find_paths(file_name, app_name, search_folders)
  if not actual_files:
    return None
  with open(actual_files[0], 'r') as reader:
    return json.load(reader)
