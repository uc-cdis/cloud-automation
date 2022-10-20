###### lambda_function.rb  is a script which will post the cloudwatch alarms to a given slack channel. 
#
#      This lambda requires the slack webhook url of the slack 
#      channel that you would like to post to and 
#
#
#      Lambda should know which function to call, in this case it should be handler.
#      Cloud watch sends the data similar to the following
#
#
#       {
#         :event {  
#           "Records": [{
#              "EventSource": "aws:sns",
#              "EventVersion": "1.0",
#              "EventSubscriptionArn": "arn:aws:sns:us-east-1:XXX:db_disk_space_alarm-Topic:XXXXXXXXXXXXXXXXXX",
#              "Sns": {
#                "Type": "Notification",
#                "MessageId": "[...]",
#                "TopicArn": "arn:aws:sns:us-east-1:XXX:db_disk_space_alarm-Topic",
#                 "Subject": "ALARM: \"db_disk_space_alarm\" in US East (N. Virginia)",
#                 "Message": "{\"AlarmName\":\"db_disk_space_alarm\",\"AlarmDescription\":null,\"AWSAccountId\":\"XXX\",\"NewStateValue\":\"ALARM\",\"NewStateReason\":\"Threshold Crossed: 1 datapoint [3.22 (29/10/17 13:20:00)] was greater than the threshold (1.0).\",\"StateChangeTime\":\"2017-10-30T13:20:35.831+0000\",\"Region\":\"US East (N. Virginia)\",\"OldStateValue\":\"INSUFFICIENT_DATA\",\"Trigger\":{\"MetricName\":\"EstimatedCharges\",\"Namespace\":\"AWS/Billing\",\"StatisticType\":\"Statistic\",\"Statistic\":\"MAXIMUM\",\"Unit\":null,\"Dimensions\":[{\"name\":\"Currency\",\"value\":\"USD\"}],\"Period\":86400,\"EvaluationPeriods\":1,\"ComparisonOperator\":\"GreaterThanThreshold\",\"Threshold\":1.0,\"TreatMissingData\":\"\",\"EvaluateLowSampleCountPercentile\":\"\"}}",
#                 "Timestamp": "[...]",
#                 "SignatureVersion": "1",
#                 "Signature": "[...]",
#                 "SigningCertUrl": "[...]",
#                 "UnsubscribeUrl": "[...]",
#                 "MessageAttributes": {}
#              }
#           }]
#         }
#       }
#
#
#      Since we only care about a few fields we need to parse the data recieved from SNS.
#      The data is sent as a json so we can access each individual field relatively easily.
#      The data then needs to be put into a format which slack can recieve. The format is
#      similar to the following.
#      
#
#      {
#        "text": "XXXX"
#      }
#
#
#      The text field is required but there are other optional fields which can be set.
#      For more inforation about these fields read https://api.slack.com/incoming-webhooks.
#
#
#
#      @author: Ed Malinowski
#      @email:  emalinowski@uchicago.edu


require 'json'
require 'net/http'
require 'uri'


def createPost(message,url)
    uri = URI.parse(url)
    request = Net::HTTP::Post.new(uri)
    request.body = message
    req_options = {
      use_ssl: uri.scheme == "https",
    }
    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
end

def processMessage(event)
    messageHash = JSON.parse(event[:event]["Records"][0]["Sns"]["Message"])
    slackMessage = {
        "text": "\
Alarm Name: #{messageHash["AlarmName"]},\
Alarm Description: #{messageHash["AlarmDescription"]},\
New State Value: #{messageHash["NewStateValue"]}, \
New State Reason: #{messageHash["NewStateReason"]}"
    }.to_json
    createPost(slackMessage,ENV["slack_webhook"])
    unless ENV["secondary_slack_webhook"].empty?
      createPost(slackMessage,ENV["secondary_slack_webhook"])
    end
end