
import json
import boto3
import sys
import os

#print('Loading function')
""" Function to define Lambda Handler """

def lambda_handler(event, context):
    #print(event)
    try:
        if event['detail']['eventName'] == 'StopLogging':
            if 'topic' in os.environ:
                client = boto3.client('cloudtrail')
                response = client.start_logging(Name=event['detail']['requestParameters']['name'])
                client = boto3.client('sns')
                response = client.publish(
                    TopicArn=os.environ['topic'],
                    Message=json.dumps({'default': json.dumps(event['detail'])}),
                    MessageStructure='json'
                    )
            else:
                print("lambda test loads")
                return event['detail']['eventName']
        else:
            print(event['detail']['eventName'])
    except Exception as e:
        print(e)
        #sys.exit();
