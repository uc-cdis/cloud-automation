import os
import config_helper

APP_NAME='tube'

conf_data = config_helper.load_json('creds.json', APP_NAME)
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
    "es.resource": os.getenv('ES_INDEX_NAME', 'null'),
    "es.input.json": 'yes',
    "es.nodes.client.only": 'false',
    "es.nodes.discovery": 'false',
    "es.nodes.data.only": 'false',
    "es.nodes.wan.only": 'true'
}

if 'null' == ES['es.resource']:
  raise Exception('ES_INDEX_NAME environment not defined')

HADOOP_HOME = os.getenv('HADOOP_HOME', '/usr/local/Cellar/hadoop/3.1.0/libexec/')
JAVA_HOME = os.getenv('JAVA_HOME', '/Library/Java/JavaVirtualMachines/jdk1.8.0_131.jdk/Contents/Home')
HADOOP_URL = os.getenv('HADOOP_URL', 'http://spark-service:9000')
ES_HADOOP_VERSION = os.getenv("ES_HADOOP_VERSION", "")
ES_HADOOP_HOME_BIN = '{}/elasticsearch-hadoop-{}'.format(os.getenv("ES_HADOOP_HOME", ""), os.getenv("ES_HADOOP_VERSION", ""))
HADOOP_HOST = os.getenv("HADOOP_HOST", "spark-service")
MAPPING_FILE = config_helper.find_paths("etlMapping.yaml", APP_NAME)[0]
