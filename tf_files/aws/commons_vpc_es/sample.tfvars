#Automatically generated from a corresponding variables.tf on 2022-07-12 11:33:44.445657

#Slack webhook to send alerts to a Slack channel. Slack webhooks are deprecated, so this may need to change at some point
#See: https://api.slack.com/legacy/custom-integrations/messaging/webhooks
slack_webhook = ""

#A Slack webhook to send alerts to a secondary channel
secondary_slack_webhook = ""

#The instance type for ElasticSearch. More information on instance types can be found here: 
#https://docs.aws.amazon.com/opensearch-service/latest/developerguide/supported-instance-types.html
instance_type = "m4.large.elasticsearch"

#The size of the attached Elastic Block Store volume, in GB
ebs_volume_size_gb = 20

#Boolean to control whether or not this cluster should be encrypted
encryption = "true"

#How many instances to have in this ElasticSearch cluster
instance_count = 3

#For tagging purposes
organization_name = "Basic Service"

#What version to use when deploying ES
es_version = "6.8"

#Whether or not to deploy a linked role for ES. A linked role is a role that allows for easier management of ES, by automatically
#granting it the access it needs. For more information, see: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/slr.html
es_linked_role = true

