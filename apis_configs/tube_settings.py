import os
try:
    # Import everything from ``local_settings``, if it exists.
    from tube.config_helper import *
except ImportError:
    # If it doesn't, look in ``/tube/tube``.
    try:
        import imp
        imp.load_source('config_helper', '/tube/tube/config_helper.py')
        print('finished importing')
    except IOError:
        print("config_helper is not found")

APP_NAME='tube'
def wrap_load_json(file_name):
  return load_json(file_name, APP_NAME)

conf_data = wrap_load_json('/tube/creds.json')
DB_HOST = conf_data.get( 'db_host', '{{db_host}}' )
DB_DATABASE = conf_data.get( 'db_database', '{{db_database}}' )
DB_USERNAME = conf_data.get( 'db_username', '{{db_username}}' )
DB_PASSWORD = conf_data.get( 'db_password', '{{db_password}}' )
JDBC = 'jdbc:postgresql://{}/{}'.format(DB_HOST, DB_DATABASE)
PYDBC = 'postgresql://{}:{}@{}:5432/{}'.format(DB_USERNAME, DB_PASSWORD, DB_HOST, DB_DATABASE)
DICTIONARY_URL = os.getenv('DICTIONARY_URL', 'https://s3.amazonaws.com/dictionary-artifacts/datadictionary/develop/schema.json')
ES_URL = os.getenv("ES_URL", "esproxy-service")

HDFS_DIR = '/result'
# Three modes: Test, Dev, Prod
RUNNING_MODE = 'Prod'
SPARK_MASTER = 'spark-service'
PARALLEL_JOBS = 1

ES = {
    "es.nodes": ES_URL,
    "es.port": '9200',
    "es.resource": 'etl',
    "es.input.json": 'yes',
    "es.nodes.client.only": 'false',
    "es.nodes.discovery": 'false',
    "es.nodes.data.only": 'false',
    "es.nodes.wan.only": 'true'
}

HADOOP_HOME = os.getenv('HADOOP_HOME', '/usr/local/Cellar/hadoop/3.1.0/libexec/')
JAVA_HOME = os.getenv('JAVA_HOME', '/Library/Java/JavaVirtualMachines/jdk1.8.0_131.jdk/Contents/Home')
HADOOP_URL = os.getenv('HADOOP_URL', 'http://spark-service:9000')
ES_HADOOP_VERSION = os.getenv("ES_HADOOP_VERSION", "")
ES_HADOOP_HOME_BIN = '{}/elasticsearch-hadoop-{}'.format(os.getenv("ES_HADOOP_HOME", ""), os.getenv("ES_HADOOP_VERSION", ""))
HADOOP_HOST = os.getenv("HADOOP_HOST", "spark-service")
