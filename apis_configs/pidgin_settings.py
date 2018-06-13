from pidgin.api import app, app_init
from os import environ
import config_helper

APP_NAME='pidgin'
def load_json(file_name):
  return config_helper.load_json(file_name, APP_NAME)

conf_data = load_json('creds.json')
config = app.config

config['PEREGRINE_API'] = 'http://peregrine-service/'
app_init(app)
application = app
