import boto3
import json
import os
from multiprocessing import Process, Pipe
from botocore.exceptions import ClientError

class BucketsParallel(object):
    """Finds total object size for all buckets"""
    def __init__(self, creds=''):
        if creds:
          self.s3 = boto3.client('s3', region_name='us-east-1', aws_access_key_id=creds["aws_access_key_id"], aws_secret_access_key=creds["aws_secret_key"])
        else:
          self.s3 = boto3.client('s3', region_name='us-east-1')
        self.bucket_list = dict()

    def add_size(self, bucket, size):
        self.bucket_list.update({bucket: size})

    def bucket_size(self, bucket, conn):
        """
        Finds total size of all objects in an s3 bucket
        """
        size=0
        response = self.s3.list_objects_v2(
            Bucket=bucket
        )
        isTruncated=True
        if 'Contents' in response:
          while isTruncated:
            if response["IsTruncated"]:
                for content in response['Contents']:
                  size = content['Size'] + size
                response = self.s3.list_objects_v2(
                    Bucket=bucket,
                    ContinuationToken=response["NextContinuationToken"]
                )
            else:
                for content in response['Contents']:
                    size = content['Size'] + size
                isTruncated=False
        else:
            size = 0
        print(f"{bucket}: {size}")
        conn.send([{"Bucket": bucket, "Size": size}])
        conn.close()
        

    def total_size(self):
        """
        Lists all buckets in account and
        sums the size of all 
        """
        print("Running in parallel")
        buckets = self.s3.list_buckets()
        # create a list to keep all processes
        processes = []
        # create a list to keep connections
        parent_connections = []
        # create a process per instance
        for bucket in buckets["Buckets"]:            
            # create a pipe for communication
            parent_conn, child_conn = Pipe()
            parent_connections.append(parent_conn)
            # create the process, pass instance and connection
            process = Process(target=self.bucket_size, args=(bucket["Name"], child_conn,))
            processes.append(process)
        # start all processes
        for process in processes:
            process.start()
        # make sure that all processes have finished
        for process in processes:
            process.join()
        instances_total=0
        for parent_connection in parent_connections:
            value = parent_connection.recv()[0]
            self.add_size(value["Bucket"], value["Size"])
            instances_total += value["Size"]
        return str(instances_total)
    
def send_email(list, total, config):
    for key in list:
        list[key]=str(list[key])+"\n"
    SENDER = f"{config['sender']}"
    RECIPIENT = f"{config['recipient']}"
    AWS_REGION = "us-east-1"
    SUBJECT = "Bucket Size Report"
    BODY_TEXT = ("Buckets with sizes:\n" f"{' '.join([key +': '+str(list[key]) for key in list.keys()])}"
                 f"Total Size: {total}"
                )
    CHARSET = "UTF-8"
    client = boto3.client('ses',region_name='us-east-1', aws_access_key_id=config["aws_access_key_id"], aws_secret_access_key=config["aws_secret_key"])
    try:
        response = client.send_email(
            Destination={
                'ToAddresses': [
                    RECIPIENT,
                ],
            },
            Message={
                'Body': {
                    'Text': {
                        'Charset': CHARSET,
                        'Data': BODY_TEXT,
                    },
                },
                'Subject': {
                    'Charset': CHARSET,
                    'Data': SUBJECT,
                },
            },
            Source=SENDER,
        )
    except ClientError as e:
        print(e.response['Error']['Message'])
    else:
        print("Email sent! Message ID:"),
        print(response['MessageId'])


# Check if there are creds files, which denotes running in a job, if not use the current environments creds.
if os.path.exists('/creds.json') and os.path.exists('/ses-creds.json'):
  with open('/ses-creds.json') as f:
    ses_data = json.load(f)
  with open('/creds.json') as f:
    data = json.load(f)
  for credential in data["credentials"]:
    buckets = BucketsParallel(credential)
    total = buckets.total_size()
    print(f"Total volume size: {total}")
    send_email(buckets.bucket_list, total, ses_data)
else:
  buckets = BucketsParallel()
  total = buckets.total_size()
  print(f"Total volume size: {total}")