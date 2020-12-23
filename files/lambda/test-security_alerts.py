#!/usr/bin/env python3
import pytest
import security_alerts

example = {'version': '0', 'id': '06ca5e7a-3b6c-0a85-0dc1-c963d8bd31f4', 'detail-type': 'AWS API Call via CloudTrail', 'source': 'aws.cloudtrail', 'account': '707767160287', 'time': '2019-09-12T19:33:22Z', 'region': 'us-east-1', 'resources': [], 'detail': {'eventVersion': '1.05', 'userIdentity': {'type': 'AssumedRole', 'principalId': 'AROAICHVNMYIWEFXZIRDW:fauzi-csoc', 'arn': 'arn:aws:sts::707767160287:assumed-role/csoc_adminvm/fauzi-csoc', 'accountId': '707767160287', 'accessKeyId': 'ASIA2JSRVZXPWWDZ6A5N', 'sessionContext': {'sessionIssuer': {'type': 'Role', 'principalId': 'AROAICHVNMYIWEFXZIRDW', 'arn': 'arn:aws:iam::707767160287:role/csoc_adminvm', 'accountId': '707767160287', 'userName': 'csoc_adminvm'}, 'webIdFederationData': {}, 'attributes': {'mfaAuthenticated': 'true', 'creationDate': '2019-09-12T19:31:40Z'}}}, 'eventTime': '2019-09-12T19:33:22Z', 'eventSource': 'cloudtrail.amazonaws.com', 'eventName': 'StopLogging', 'awsRegion': 'us-east-1', 'sourceIPAddress': '128.135.61.125', 'userAgent': 'console.amazonaws.com', 'requestParameters': {'name': 'arn:aws:cloudtrail:us-east-1:707767160287:trail/cdistest_management_trail'}, 'responseElements': None, 'requestID': '8e0bdee5-8626-4ad4-b5cf-29bada7bef17', 'eventID': '0da7164e-a62d-4bda-811c-4facfbc55df4', 'readOnly': False, 'eventType': 'AwsApiCall'}}

def test_answer():
    assert security_alerts.lambda_handler(example,'') 

