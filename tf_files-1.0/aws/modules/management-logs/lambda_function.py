"""

lambda_function.py  is a script file destinated to be executed by AWS lambda service when a stream of logs
        come into the CSOC account from a different AWS account. The way these accounts get tied together is by
        logs subscription logs that should be added in the source account. 

        For the source account we need a CloudWatch Log group and when everything is properly set in the CSOC account,
        add the subscription to the group. Subscription cannot be created in the console, but manually doing it
        from an EC2 instance that has the proper access should be like the following:

aws logs put-subscription-filter --log-group-name "<log group name>" --filter-name "<a name>" --destination-arn "arn:aws:logs:<region>:<destination account id>:destination:<destination name>" --filter-pattern '<something you want to filter, otherwise leave blank to send everything>' --region <source region>


        Lambda should know which function to call, in this case it should be handler.

        Data comes in like the following, or at least it is what the 'event' argument should look like:

{'Records': [{'kinesis': {'kinesisSchemaVersion': '1.0', 'partitionKey': '81a6fb0168975347bb8d9ed7cd945367', 'sequenceNumber': '49582863307409319741090962153614735877224301205609512962', 'data': 'H4sIAAAAAAAAAMWQS2vDMBCE/4rQKYEI9JZl6CG0aU5pocmthCDbaiqwJSPLaUPIf6/6gpBrD70tM8vMfnuCnR0Gs7ebY29hCe/mm/lutViv58sFnMHw5m3MssJKSUUkpoXKchv2yxjGPjuNPfSt8TYdyLexTtGaLjt5dn7nQ2ORGdMrcj0iiiLKkeSIY+QQrriWxkhdcWpqplhOGMZqqKPrkwv+3rXJxgGWz5c1u8sVuP0qXRysT5+LJ+ia3M2Y5owXimuNBSkkxVozpbngmHNBOKZUUVxoKRjXQjBNJcOq4PmA5PJHkukyHBGUZlVSgjGe/X4qx69MBFQCIkqmSkzAFRq4fXp8eFZS4m0JetPtRu/eJ3UMvhxyRj57WoKfCYTeetuAlxDBONgIYggJVEcwGV1zg6fwPPsbk/gHproNwzUTPG/PH2fPgL5uAgAA', 'approximateArrivalTimestamp': 1522078629.716}, 'eventSource': 'aws:kinesis', 'eventVersion': '1.0', 'eventID': 'shardId-000000000000:49582863307409319741090962153614735877224301205609512962', 'eventName': 'aws:kinesis:record', 'invokeIdentityArn': 'arn:aws:iam::433568766270:role/devplanetv1_lambda', 'awsRegion': 'us-east-1', 'eventSourceARN': 'arn:aws:kinesis:us-east-1:433568766270:stream/devplanetv1_stream'}, {'kinesis': {'kinesisSchemaVersion': '1.0', 'partitionKey': 'fa9401770aca21f01338db54f9519935', 'sequenceNumber': '49582863307409319741090962153615944803043915903503695874', 'data': 'H4sIAAAAAAAAAO1T22rcMBD9FeGnhEZeXWxJNrQQaJq+BArZt/WyyJYcu/GtljYlpPvvHXt3c+kNSl6DwUhz0ZyZOechaK1z+sYu7wcbpMHH8+X55uri+vr88iI4C/rvnR3BLImUQlJBmJJgbvqby7HfDuAx9m5odGf9Hd07rv1odQue221uR3BYF97pMQRXWPSd1zU86UJXWTuY/gYbOzT9fWs7j2lMZcRoIgVub3PzdeMr3VWd2TwG51HJbWRIkeeUW8YTZXlJtC210NoYXZKyFJLxXMmSc6KUyfMiibUS0sgijyYUANNtc1eM9eDrvvtUNx4ABenqeS+b5yHBeu7s4g5AToEPQW2gQc6TiEdKcBURGsFsqGQqUiwRiYiV4oRBP4oqyRX8uSJgFJGIAICvYexetzBBGjNGpIolJYScHdcBzz9kU9EsSLNgNdQmRUz90MOQIvJjtN/gCnUXksV8jSgJWSh5SNHJKXrgEYKBO1R3iCcc5fewgh1aXfUdutIjYgLROOUipRQxQtUaXV4s0WIDePzWofcf0I2FFWlvDZL77OmpCLXOFg6dfF4uvyxoOCWTU8RQZbWx+3JSHeJPKHLfa19UcIayRT9aRE6zrMuCsyxwM0XmzpyH3HG2mr64tXBMofFHomxqM8e9dvFZsIMST5T8tUynW7sHdKDaDGmyukEX9sl/oOTsHnrze+K/CP2YdeiK6EQXItaYmTjGlFqFtWAxJraQRJU0zo2acxqd2+YAGjjwO1ID65qtQCcqYsEIPxbD3rZAa29xpV11CDri2s+l6p2fHfWAgcSYRVgITAkLbcHCugOBdLqZH2y1g9tmOzZzQuX94NLFAhjIQxLSNIr4Qg/1L+M7bpHwpCw4wSAV/td+dzsA9TqNxf+vMYymb8XEAkSymISRPsrkHaSRNcqyLHihlaMUJsckB9DLdMTzfY7u8TQhXDQ18OEY+mcd9Fv/poM3HbzUwXr3E2dXYDuiBwAA', 'approximateArrivalTimestamp': 1522078630.322}, 'eventSource': 'aws:kinesis', 'eventVersion': '1.0', 'eventID': 'shardId-000000000000:49582863307409319741090962153615944803043915903503695874', 'eventName': 'aws:kinesis:record', 'invokeIdentityArn': 'arn:aws:iam::433568766270:role/devplanetv1_lambda', 'awsRegion': 'us-east-1', 'eventSourceARN': 'arn:aws:kinesis:us-east-1:433568766270:stream/devplanetv1_stream'}]}



@return: Nothing is returned, but the funtion would insert the transformed data to kinesis firehoses that would
         take care of putting the data in the final destination.

        Data transformed (from the above example should look like the following before being inserted into the firehoses:


[{'Data': '{"messageType": "DATA_MESSAGE", "owner": "707767160287", "logGroup": "devplanetv1", "logStream": "login_node-auth-ip-172-24-64-40-i-0b496aa69b42ac373", "subscriptionFilters": ["devplanetv1_subscription"], "timestamp": "2018-03-26T15:37:01", "message": {"log": "Mar 26 15:37:01 ip-172-24-64-40 CRON[7660]: pam_unix(cron:session): session opened for user root by (uid=0)"}}'}, {'Data': '{"messageType": "DATA_MESSAGE", "owner": "707767160287", "logGroup": "devplanetv1", "logStream": "login_node-auth-ip-172-24-64-40-i-0b496aa69b42ac373", "subscriptionFilters": ["devplanetv1_subscription"], "timestamp": "2018-03-26T15:37:01", "message": {"log": "Mar 26 15:37:01 ip-172-24-64-40 CRON[7660]: pam_unix(cron:session): session closed for user root"}}'}]

[{'Data': '{"messageType": "DATA_MESSAGE", "owner": "707767160287", "logGroup": "devplanetv1", "logStream": "kubernetes.var.log.containers.sheepdog-deployment-1517421976-mkbdj_thanhnd_sheepdog-b4f3e4d0cbb13e2398e3f0aefa6aaddaf0ff6723b87f33088dbbc95a867d7cb4.log", "subscriptionFilters": ["devplanetv1_subscription"], "timestamp": "2018-03-26T15:36:11", "message": {"log": "[pid: 28|app: 0|req: 2384/7253] 10.2.73.1 () {34 vars in 393 bytes} [Mon Mar 26 15:36:11 2018] GET /_status => generated 7 bytes in 4 msecs (HTTP/1.1 200) 2 headers in 78 bytes (1 switches on core 0)\\n", "stream": "stderr", "docker": {"container_id": "b4f3e4d0cbb13e2398e3f0aefa6aaddaf0ff6723b87f33088dbbc95a867d7cb4"}, "kubernetes": {"container_name": "sheepdog", "namespace_name": "thanhnd", "pod_name": "sheepdog-deployment-1517421976-mkbdj", "pod_id": "0a9ac65a-2d55-11e8-a625-0ec708f15bd8", "labels": {"app": "sheepdog", "date": "1521656203", "pod-template-hash": "1517421976"}, "host": "ip-172-24-66-102.ec2.internal", "master_url": "https://10.3.0.1:443/api", "namespace_id": "b039fc30-2173-11e8-a625-0ec708f15bd8"}}}'}, {'Data': '{"messageType": "DATA_MESSAGE", "owner": "707767160287", "logGroup": "devplanetv1", "logStream": "kubernetes.var.log.containers.sheepdog-deployment-1517421976-mkbdj_thanhnd_sheepdog-b4f3e4d0cbb13e2398e3f0aefa6aaddaf0ff6723b87f33088dbbc95a867d7cb4.log", "subscriptionFilters": ["devplanetv1_subscription"], "timestamp": "2018-03-26T15:36:11+00:00", "message": {"log": "- - - [26/Mar/2018:15:36:11 +0000] \\"GET /_status HTTP/1.1\\" 200 7 \\"-\\" \\"Go-http-client/1.1\\"\\n", "stream": "stdout", "docker": {"container_id": "b4f3e4d0cbb13e2398e3f0aefa6aaddaf0ff6723b87f33088dbbc95a867d7cb4"}, "kubernetes": {"container_name": "sheepdog", "namespace_name": "thanhnd", "pod_name": "sheepdog-deployment-1517421976-mkbdj", "pod_id": "0a9ac65a-2d55-11e8-a625-0ec708f15bd8", "labels": {"app": "sheepdog", "date": "1521656203", "pod-template-hash": "1517421976"}, "host": "ip-172-24-66-102.ec2.internal", "master_url": "https://10.3.0.1:443/api", "namespace_id": "b039fc30-2173-11e8-a625-0ec708f15bd8"}}}'}]


The actual log that would be the same as in a rown in CloudWatchLogs 
would be the "message" part of the json. 

Since we receive a list of records, we need to iterate through the list,
get the actual timestamp (when possible) and create a new single row,
append it to a new list, chunk it if necesary. We can't just send a list
longer than 500 to the firehose without throttling it.

The flow is everytime Kinesis Stream receives something, it'll invoke this
function by calling the handler function. The function nice_it would make 
the records nice, and date_it would try to get any day from the actual log
if not then datetime.now() is used.



@author: Fauzi Gomez
@email:  fauzi@uchicago.edu

"""

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
      
      
def date_it(line):
    """
    The stream comes in with a timestamp but is from where the stream was receibed and not actually
    what's in the log like.
    We want to get anything we can from the log line and transform it to ISO8601 so we can index 
    better in ES and run fancy queries with Kibana
    """
    #print(line)
    fecha = json.loads(line['message'])['eventTime']
    # 2019-01-02T19:14:07Z
    fecha = datetime.datetime.strptime(json.loads(line['message'])['eventTime'],'%Y-%m-%dT%H:%M:%SZ').isoformat()
    #print(fecha)
    line['timestamp'] = fecha
    return line
    
    
def nice_it(r_data):
    """
    We just filter what we dont want and put what we care about 
    """
    individuals = []
    metadata = copy.deepcopy(r_data)
    del metadata['logEvents']
    for line in r_data['logEvents']:
        new_meta = copy.deepcopy(metadata)
        #may need to fix this if we need ES
        line = date_it(line)
        new_meta['timestamp'] = line['timestamp']
        #new_meta['message'] = json.loads(json.dumps(line['message']))
        try:
            # Let's see if it is JSONable, Fluentd stuff should
            cosa = json.loads(line['message'])
        except:
            # If it isn't JSON, let's make it JSON
            cosa = { 'log' : line['message'] }
        new_meta['message'] = cosa #line['message']
        individuals.append(new_meta)
        del new_meta
        #print(new_meta)
    del metadata
    return individuals
    
def handler(event, context):
    if os.environ.get('stream_name') is not None:
        client = boto3.client('firehose')
    else:
        output = ''
    #print(len(event['Records']))
    for record in event['Records']:
        compressed_record_data = record['kinesis']['data']
        record_data = nice_it(json.loads(zlib.decompress(base64.b64decode(compressed_record_data), 16+zlib.MAX_WBITS).decode('utf-8')))
        #print(record_data)
        #record_data = nice_it(record_data)
        for log_event_chunk in chunker(record_data, MESSAGE_BATCH_MAX_COUNT):
            message_batch = [{'Data': json.dumps(x)} for x in log_event_chunk]
            #print(message_batch)
            if message_batch:
                if os.environ.get('stream_name') is not None:
                    client.put_record_batch(DeliveryStreamName=os.environ['stream_name']+'_to_es', Records=message_batch)
                    client.put_record_batch(DeliveryStreamName=os.environ['stream_name']+'_to_s3', Records=message_batch)
                    #print(message_batch)
                else:
                    #return message_batch
                    output += str(message_batch)

    if 'output' in locals():
        print(output)
        return output
