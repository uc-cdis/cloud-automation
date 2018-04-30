import config_helper
import os
import time

# WORKSPACE == Jenkins workspace
TEST_ROOT=os.getenv('WORKSPACE',os.getenv('XDG_RUNTIME_DIR', '/tmp')) + '/test_config_helper/' + str(int(time.time()))
APP_NAME='test_config_helper'
TEST_JSON = '''
{
  "a": "A",
  "b": "B",
  "c": "C"
}
'''
TEST_FILENAME='bla.json'

config_helper.XDG_DATA_HOME=TEST_ROOT

def setup():
  test_folder = TEST_ROOT + '/cdis/' + APP_NAME
  if not os.path.exists(test_folder):
    os.makedirs(test_folder)
  with open(test_folder + '/' + TEST_FILENAME, 'w') as writer:
    writer.write(TEST_JSON)

def test_find_paths():
  setup()
  path_list = config_helper.find_paths(TEST_FILENAME, APP_NAME)
  assert len(path_list) == 1
  bla_path = TEST_ROOT + '/cdis/' + APP_NAME + '/' + TEST_FILENAME
  assert os.path.exists(bla_path)
  assert path_list[0] == bla_path

def test_load_json():
  setup()
  data = config_helper.load_json(TEST_FILENAME, APP_NAME)
  for key in ['a','b','c']:
    assert data[key] == key.upper()
