#Automatically generated from a corresponding variables.tf on 2022-07-13 12:22:29.434675

#The name of the VPC this storage gateway will be spun up on
vpc_name= ""

#
#The ID of the AMI (Amazon Machine Image) used by machines spun up by this module
ami_id = ""

#The size of the storage gateway machine's root storage, in GiB
size = 80

#The size of the caching disk, in GiB
cache_size = 150

#The name of an S3 bucket for transfers
s3_bucket = ""

#The name of an AWS SSH key pair to attach to EC2 instances. For more information,
#see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html
key_name = ""

