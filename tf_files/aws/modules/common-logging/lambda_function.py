"""

lambda_function.py  is a script filed destinated to be executed by AWS lambda service when a stream of logs
        come into the CSOC account from a different AWS account. The way these accounts get tied together is by
        logs subscription logs that should be added in the source account. 

        For the source account we need a CloudWatch Log group and when everything is properly set in the CSOC account,
        add the subscription to the group. Subscription cannot be created in the console, but manually doing it
        from an EC2 instance that has the proper access should be like the following:

aws logs put-subscription-filter --log-group-name "<log group name>" --filter-name "<a name>" --destination-arn "arn:aws:logs:<region>:<destination account id>:destination:<destination name>" --filter-pattern '<something you want to filter, otherwise leave blank to send everything>' --region <source region>


        Lambda should know which function to call, in this case it should be handler.

        Data comes in like the following, or at least it is what the 'event' argument should look like:

{'Records': [{'kinesis': {'kinesisSchemaVersion': '1.0', 'partitionKey': '81a6fb0168975347bb8d9ed7cd945367', 'sequenceNumber': '49582863307409319741090962153614735877224301205609512962', 'data': 'H4sIAAAAAAAAAMWQS2vDMBCE/4rQKYEI9JZl6CG0aU5pocmthCDbaiqwJSPLaUPIf6/6gpBrD70tM8vMfnuCnR0Gs7ebY29hCe/mm/lutViv58sFnMHw5m3MssJKSUUkpoXKchv2yxjGPjuNPfSt8TYdyLexTtGaLjt5dn7nQ2ORGdMrcj0iiiLKkeSIY+QQrriWxkhdcWpqplhOGMZqqKPrkwv+3rXJxgGWz5c1u8sVuP0qXRysT5+LJ+ia3M2Y5owXimuNBSkkxVozpbngmHNBOKZUUVxoKRjXQjBNJcOq4PmA5PJHkukyHBGUZlVSgjGe/X4qx69MBFQCIkqmSkzAFRq4fXp8eFZS4m0JetPtRu/eJ3UMvhxyRj57WoKfCYTeetuAlxDBONgIYggJVEcwGV1zg6fwPPsbk/gHproNwzUTPG/PH2fPgL5uAgAA', 'approximateArrivalTimestamp': 1522078629.716}, 'eventSource': 'aws:kinesis', 'eventVersion': '1.0', 'eventID': 'shardId-000000000000:49582863307409319741090962153614735877224301205609512962', 'eventName': 'aws:kinesis:record', 'invokeIdentityArn': 'arn:aws:iam::433568766270:role/devplanetv1_lambda', 'awsRegion': 'us-east-1', 'eventSourceARN': 'arn:aws:kinesis:us-east-1:433568766270:stream/devplanetv1_stream'}, {'kinesis': {'kinesisSchemaVersion': '1.0', 'partitionKey': 'fa9401770aca21f01338db54f9519935', 'sequenceNumber': '49582863307409319741090962153615944803043915903503695874', 'data': 'H4sIAAAAAAAAAO1T22rcMBD9FeGnhEZeXWxJNrQQaJq+BArZt/WyyJYcu/GtljYlpPvvHXt3c+kNSl6DwUhz0ZyZOechaK1z+sYu7wcbpMHH8+X55uri+vr88iI4C/rvnR3BLImUQlJBmJJgbvqby7HfDuAx9m5odGf9Hd07rv1odQue221uR3BYF97pMQRXWPSd1zU86UJXWTuY/gYbOzT9fWs7j2lMZcRoIgVub3PzdeMr3VWd2TwG51HJbWRIkeeUW8YTZXlJtC210NoYXZKyFJLxXMmSc6KUyfMiibUS0sgijyYUANNtc1eM9eDrvvtUNx4ABenqeS+b5yHBeu7s4g5AToEPQW2gQc6TiEdKcBURGsFsqGQqUiwRiYiV4oRBP4oqyRX8uSJgFJGIAICvYexetzBBGjNGpIolJYScHdcBzz9kU9EsSLNgNdQmRUz90MOQIvJjtN/gCnUXksV8jSgJWSh5SNHJKXrgEYKBO1R3iCcc5fewgh1aXfUdutIjYgLROOUipRQxQtUaXV4s0WIDePzWofcf0I2FFWlvDZL77OmpCLXOFg6dfF4uvyxoOCWTU8RQZbWx+3JSHeJPKHLfa19UcIayRT9aRE6zrMuCsyxwM0XmzpyH3HG2mr64tXBMofFHomxqM8e9dvFZsIMST5T8tUynW7sHdKDaDGmyukEX9sl/oOTsHnrze+K/CP2YdeiK6EQXItaYmTjGlFqFtWAxJraQRJU0zo2acxqd2+YAGjjwO1ID65qtQCcqYsEIPxbD3rZAa29xpV11CDri2s+l6p2fHfWAgcSYRVgITAkLbcHCugOBdLqZH2y1g9tmOzZzQuX94NLFAhjIQxLSNIr4Qg/1L+M7bpHwpCw4wSAV/td+dzsA9TqNxf+vMYymb8XEAkSymISRPsrkHaSRNcqyLHihlaMUJsckB9DLdMTzfY7u8TQhXDQ18OEY+mcd9Fv/poM3HbzUwXr3E2dXYDuiBwAA', 'approximateArrivalTimestamp': 1522078630.322}, 'eventSource': 'aws:kinesis', 'eventVersion': '1.0', 'eventID': 'shardId-000000000000:49582863307409319741090962153615944803043915903503695874', 'eventName': 'aws:kinesis:record', 'invokeIdentityArn': 'arn:aws:iam::433568766270:role/devplanetv1_lambda', 'awsRegion': 'us-east-1', 'eventSourceARN': 'arn:aws:kinesis:us-east-1:433568766270:stream/devplanetv1_stream'}]}



@return: Nothing is returned, but the funtion would insert the transformed data to kinesis firehoses that wwould
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
import urllib.request
import urllib.parse

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

slower_checker = ["revproxy","sheepdog","peregrine"]


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
    fecha = None
    for a_datetime in different_datetimes:
        try:
            fecha = re.search(a_datetime['pattern'],line['message'])
        except:
            print(format("there was an error with '{}' and '{}'",a_datetime['pattern'],line['message']))
    
        if fecha:
            if not a_datetime['format']:
                #print(float(fecha.group())) This is squid
                fecha = datetime.datetime(*time.strptime(time.ctime(float(fecha.group())))[0:6]).isoformat()
            elif not "%Y" in a_datetime['format']:
                fechat = fecha.group() + ' ' + time.strftime("%Y", time.localtime(time.time()))
                forma = a_datetime['format'] + ' %Y'
                fecha = datetime.datetime.strptime(fechat,forma).isoformat()
            else:
                try:
                    fecha = datetime.datetime.strptime(fecha.group(),a_datetime['format']).isoformat()
                except:
                    if a_datetime['format'] == '%Y-%m-%d %H:%M:%S %z':
                        try:
                            fecha = datetime.datetime.strptime(fecha.group(),'%Y-%m-%d %H:%M:%S').isoformat()
                        except:
                            fecha = datetime.datetime.now().isoformat()
            break
    #print(line)
    if not fecha:
        fecha = datetime.datetime.now().isoformat()
    
    line['timestamp'] = fecha

    return line


def send_it_out(slack_text,response_time):

    bar_color = "#FF0000"
    data = {"text": slack_text,
                "attachments": [
                    {"title": "Slow Response notification: ({0} seconds)".format(response_time),
                     "color": bar_color
                    }]
                }

    json_data = json.dumps(data)
    data = json_data.encode('ascii')

    if os.environ.get('slack_webhook') is not None:
        url = os.environ.get('slack_webhook')
        slack_request  = urllib.request.Request(url=url,data=data, headers={"Content-type": "application/json"},method='POST')
        slack_response = urllib.request.urlopen(slack_request,timeout=1)

        respData = slack_response.read()

        if respData.decode('utf-8') != 'ok':
            print('\n Something went wrong. Unable to post pytest report on Slack channel. Slack Response:', str(respData))



def check_speed(event,logGroup):
    """
    This function would check the speed in which the service in question took to respond and
    would send out a notification to a slack channel expresed as env variable
    """


    if os.environ.get('threshold') is not None:
        threshold = float(os.environ.get('threshold'))
    else:
        threshold = 4.00

    response_time = 100.00
    

    try:
    
        response_time = float(event["http_response_time"])
        #print("response_time = " + str(response_time) + " threshold = " + str(threshold))
    
        if response_time > threshold:
            bar_color = "#FF0000"

            refer = event["http_referer"]
            reque = event["http_request"]

            if "?" in event["http_referer"]:
                sub   = event["http_referer"].split("?")
                refer = sub[0] + "?..."

            if "?" in event["http_request"]:
                sub   = event["http_request"].split("?")
                reque = sub[0] + "?..."

            slack_text = "Environment: {0}\n\tPod: {1}\n\tRequest: {2}\n\tReferer: {3}\n\tClient IP: {4}\n\tAccess Date: {5}" \
                     "".format(logGroup, event["kubernetes"]["pod_name"], reque, refer,event["network_client_ip"],event["date_access"])

            send_it_out(slack_text,event["http_response_time"])

    except Exception as e:
        if not str(e) == "'http_response_time'":
            print(e)
        #return


    
def nice_it(r_data):
    """
    We just filter what we dont want and put what we care about 
    """
    individuals = []
    metadata = copy.deepcopy(r_data)
    del metadata['logEvents']

    checkSpeed = False

    if any(substring in r_data["logStream"] for substring in slower_checker):
        checkSpeed = True


    for line in r_data['logEvents']:
        new_meta = copy.deepcopy(metadata)
        line = date_it(line)
        new_meta['timestamp'] = line['timestamp']

        if checkSpeed:
            check_speed(json.loads(line['message']),r_data["logGroup"])

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
        #record_data = nice_it(record_data)
        for log_event_chunk in chunker(record_data, MESSAGE_BATCH_MAX_COUNT):
            message_batch = [{'Data': json.dumps(x)} for x in log_event_chunk]
            if message_batch:
                if os.environ.get('stream_name') is not None:
                    client.put_record_batch(DeliveryStreamName=os.environ['stream_name']+'_to_es', Records=message_batch)
                    client.put_record_batch(DeliveryStreamName=os.environ['stream_name']+'_to_s3', Records=message_batch)
                else:
                    #return message_batch
                    output += str(message_batch)

    if 'output' in locals():
        print(output)
        return output

