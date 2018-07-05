from pidgin.app import app
from os import environ
import config_helper

APP_NAME='pidgin'
def load_json(file_name):
  return config_helper.load_json(file_name, APP_NAME)

#conf_data = load_json('creds.json')
config = app.config

config['API_URL'] = 'http://peregrine-service/v0/submission/graphql/'
#app_init(app)
application = app
