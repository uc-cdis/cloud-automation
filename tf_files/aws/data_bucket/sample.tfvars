#Automatically generated from a corresponding variables.tf on 2022-07-12 12:55:22.764041

#The name of the bucket to be created
bucket_name= ""

#Value for 'Environment' key to tag the new resources with
environment= ""

#This variable is used to conditionally create a cloud trail. 
#Using this module to create another bucket in the same "environment" with a nonzero count for this variable will 
#result in an error because aspects of the cloud trail will already exist.
cloud_trail_count = "1"

