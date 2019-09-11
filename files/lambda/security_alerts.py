
import json
import boto3
import sys
import os

#print('Loading function')
""" Function to define Lambda Handler """

def lambda_handler(event, context):
    #print(event)
    try:
        client = boto3.client('cloudtrail')
        if event['detail']['eventName'] == 'StopLogging':
            response = client.start_logging(Name=event['detail']['requestParameters']['name'])
            print(response)
            client2 = boto3.client('sns')
            response = client2.publish(
                TopicArn=os.environ['topic'],
                Message=json.dumps({'default': json.dumps(event['detail'])}),
                MessageStructure='json'
                )
            print(response)
        else:
            print(event['detail']['eventName'])
    except Exception as e:
        print(e)
        sys.exit();

