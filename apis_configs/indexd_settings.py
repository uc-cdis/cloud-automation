from indexd.index.drivers.alchemy import SQLAlchemyIndexDriver
from indexd.alias.drivers.alchemy import SQLAlchemyAliasDriver
from indexd.auth.drivers.alchemy import SQLAlchemyAuthDriver
import config_helper

APP_NAME='indexd'
def load_json(file_name):
  return config_helper.load_json(file_name, APP_NAME)

conf_data = load_json('creds.json')

usr = conf_data.get('db_username', '{{db_username}}')
db = conf_data.get('db_database', '{{db_database}}')
psw = conf_data.get('db_password', '{{db_password}}')
pghost = conf_data.get('db_host', '{{db_host}}')
pgport = 5432
index_config = conf_data.get('index_config')
CONFIG = {}

CONFIG['JSONIFY_PRETTYPRINT_REGULAR'] = False
CONFIG['INDEX'] = {
'driver': SQLAlchemyIndexDriver('postgresql+psycopg2://{usr}:{psw}@{pghost}:{pgport}/{db}'.format(
    usr=usr,
    psw=psw,
    pghost=pghost,
    pgport=pgport,
    db=db,
), index_config=index_config),
}

CONFIG['ALIAS'] = {
'driver': SQLAlchemyAliasDriver('postgresql+psycopg2://{usr}:{psw}@{pghost}:{pgport}/{db}'.format(
    usr=usr,
    psw=psw,
    pghost=pghost,
    pgport=pgport,
    db=db,
)),
}

AUTH = SQLAlchemyAuthDriver('postgresql+psycopg2://{usr}:{psw}@{pghost}:{pgport}/{db}'.format(
    usr=usr,
    psw=psw,
    pghost=pghost,
    pgport=pgport,
    db=db,
))

settings = {'config': CONFIG, 'auth': AUTH}
