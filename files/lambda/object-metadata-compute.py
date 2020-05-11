import os
import hashlib
import json
from urllib.parse import unquote_plus
import boto3

CHUNK_SIZE = 1024*1024*10


# This Lambda function parses JSON that is encoded into the Amazon S3 batch
# operations manifest containing lines like this:
#
# bucket,key
# bucket,key
# bucket,key
#
def lambda_handler(event, context):
    # Instantiate boto client
    s3Client = boto3.client('s3', aws_access_key_id=os.getenv("ACCESS_KEY_ID"), aws_secret_access_key=os.getenv("SECRET_ACCESS_KEY"))
    # Parse job parameters from S3 batch operations
    invocationId = event['invocationId']
    invocationSchemaVersion = event['invocationSchemaVersion']

    # Prepare results
    results = []

    # S3 batch operations currently only passes a single task at a time in the array of tasks.
    task = event['tasks'][0]

    # Extract the task values we might want to use
    taskId = task['taskId']
    s3Key = task['s3Key']
    s3BucketArn = task['s3BucketArn']
    s3BucketName = s3BucketArn.split(':::')[-1]
    my_md5 = hashlib.md5()
    try:
        # Assume it will succeed for now
        resultCode = 'Succeeded'
        resultString = ''

        response = s3Client.get_object(
          Bucket=s3BucketName,
          Key=unquote_plus(s3Key)
        )
        res = response["Body"]
        data = res.read(CHUNK_SIZE)
        while data:
            my_md5.update(data)
            data = res.read(CHUNK_SIZE)
        output = {"md5":  my_md5.hexdigest(), "size": response['ContentLength']}
        resultString = json.dumps(output)

    except Exception as e:
        # If we run into any exceptions, fail this task so batch operations does not retry it and
        # return the exception string so we can see the failure message in the final report
        # created by batch operations.
        resultCode = 'PermanentFailure'
        resultString = 'Exception: {}'.format(e)
    finally:
        # Send back the results for this task.
        results.append({
            'taskId': taskId,
            'resultString': resultString,
            'resultCode': resultCode
        })

    return {
        'invocationSchemaVersion': invocationSchemaVersion,
        'treatMissingKeysAs': 'PermanentFailure',
        'invocationId': invocationId,
        'results': results
    }