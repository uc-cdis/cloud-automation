import base64
import json
import itertools
import zlib
import boto3
import datetime
import time
import re
import copy
import os

MESSAGE_BATCH_MAX_COUNT = 500 #limit from firehose put_record_batch api


# fluentd type 1 -> 2018-03-08 14:41:57 +0000  ->  '%Y-%m-%d %H:%M:%S %z'
fluentd1 = { 'pattern' : '20[0-9]{2}-(0?[1-9]|1[0-2])-([0-2]?[1-9]|3[01])\s*([0-1]?[0-9]|2[0-4])(:[0-5][0-9]){2}\s*(\+[0-9]{4}|\+[A-Z]{3})?','format':'%Y-%m-%d %H:%M:%S %z'}
# fluentd type 2 -> Thu Mar 8 14:42:27 2018  ->  '%a %b %d %H:%M:%S %Y'
fluentd2 = { 'pattern' : '[MTWFS][ouehra][neduit]\s*[JFMASOND][aepuco][nbrylgptvc]\s*([0-2]?[0-9]|3[01])\s*([0-1]?[0-9]|2[0-4])(:[0-5][0-9]){2}\s*20[0-9]{2}','format':'%a %b %d %H:%M:%S %Y'}
# fluentd type 3 -> 08/Mar/2018:14:42:27 +0000  -> '%d/%b/%Y:%H:%M:%S %z'
fluentd3 = { 'pattern' : '([0-2]?[1-9]|3[01])/([A-S][a-z]{2})/20[0-9]{2}:([0-1]?[0-9]|2[0-4])(:[0-5][0-9]){2}\s*(\+[0-9]{4}|\+[A-Z]{3})?', 'format' : '%d/%b/%Y:%H:%M:%S %z'}
# fluentd type 4 -> Thu Mar 08 14:42:27.570065 2018  ->  '%a %b %d %H:%M:%S.%f %Y'
fluentd4 = { 'pattern' : '[MTWFS][ouehra][neduit]\s*[JFMASOND][aepuco][nbrylgptvc]\s*([0-2]?[0-9]|3[01])\s*([0-1]?[0-9]|2[0-4])(:[0-5][0-9]){2}\.[0-9]{6}\s*20[0-9]{2}', 'format' : '%a %b %d %H:%M:%S.%f %Y'}

# Syslogs (also auth) type -> Apr 8 14:42:01  ->  '%b %d %H:%M:%S'
syslog = { 'pattern' : '[JFMASOND][aepuco][nbrylgptvc]\s*([0-2]?[0-9]|3[01])\s*([0-1]?[0-9]|2[0-4])(:[0-5][0-9]){2}', 'format' : '%b %d %H:%M:%S' }

#squid like -> 1520520148.130 
squid = { 'pattern' : '[0-9]{10}\.[0-9]{3}', 'format' : None }

different_datetimes = fluentd1, fluentd2, fluentd3, fluentd4, syslog, squid


def chunker(iterable, chunksize):
  """
  Return elements from the iterable in `chunksize`-ed lists. The last returned
  chunk may be smaller (if length of collection is not divisible by `chunksize`).

  >>> print list(chunker(xrange(10), 3))
  [[0, 1, 2], [3, 4, 5], [6, 7, 8], [9]]
  """
  i = iter(iterable)
  while True:
      wrapped_chunk = [list(itertools.islice(i, int(chunksize)))]
      if not wrapped_chunk[0]:
          break
      yield wrapped_chunk.pop()
      
      
def dateIt(line):
    """
    The stream comes in with a timestamp but in a integer type data.
    We want to transfor it to ISO8601 so we can index better in ES and
    run fancy queries with Kibana
    """
    #print(str(line))
    for a_datetime in different_datetimes:
        #for y in lines:
        try:
            fecha = re.search(a_datetime['pattern'],line['message'])
            #print(fecha)
        except:
            print(format("there was an error with '{}' and '{}'",a_datetime['pattern'],line['message']))
    
        if fecha:
            #print (fecha)
            if not a_datetime['format']:
                #print(float(fecha.group())) This is squid
                fecha = datetime.datetime(*time.strptime(time.ctime(float(fecha.group())))[0:6]).isoformat()
            elif not "%Y" in a_datetime['format']:
                fechat = fecha.group() + ' ' + time.strftime("%Y", time.localtime(time.time()))
                forma = a_datetime['format'] + ' %Y'
                fecha = datetime.datetime.strptime(fechat,forma).isoformat()
            else:
                fecha = datetime.datetime.strptime(fecha.group(),a_datetime['format']).isoformat()
            line['timestamp'] = fecha            
                #print(line)
        #else:
        #    print("NOOOOO")
    return line
    #print(line['timestamp'])
    
    
    
def niceIt(r_data):
    """
    We just filter what we dont want and put what we care about 
    """
    individuals = []
    metadata = copy.deepcopy(r_data)
    del metadata['logEvents']
    for line in r_data['logEvents']:
        new_meta = copy.deepcopy(metadata)
        #print(line)
        line = dateIt(line)
        new_meta['timestamp'] = line['timestamp']
        #new_meta['message'] = json.loads(json.dumps(line['message']))
        try:
            # Let's see if it is JSONable, Fluentd stuff should
            cosa = json.loads(line['message'])
            #print(cosa)
        except:
            # If it ain't JSON, let's make it JSON
            cosa = { 'log' : line['message'] }
            #print('plain')
        new_meta['message'] = cosa #line['message']
        individuals.append(new_meta)
        del new_meta
        #print(new_meta)
    del metadata
    return individuals
    
def handler(event, context):
    client = boto3.client('firehose')
    for record in event['Records']:
        compressed_record_data = record['kinesis']['data']
        #firehose = str(record['eventSourceARN'].split(':')[5].split('/')[1]) + '_firehose'
        #For practical reasons we are calling the firehose the same name 
        # of the stream plus _firehose
        #print(firehose)
        record_data = json.loads(zlib.decompress(base64.b64decode(compressed_record_data), 16+zlib.MAX_WBITS))
        #print(record_data)
        record_data = niceIt(record_data)
        #print(record_data)
        for log_event_chunk in chunker(record_data, MESSAGE_BATCH_MAX_COUNT):
            #print(log_event_chunk)
            #dateIT(log_event_chunk)
            message_batch = [{'Data': json.dumps(x)} for x in log_event_chunk]
            if message_batch:
                #print(message_batch)
                client.put_record_batch(DeliveryStreamName=os.environ['stream_name']+'_to_es', Records=message_batch)
                client.put_record_batch(DeliveryStreamName=os.environ['stream_name']+'_to_s3', Records=message_batch)
                #print('')

