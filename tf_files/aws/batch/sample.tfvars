#A tag used to identify resources associated with this job. 
job_id = ""

#This is a prefix that will be applied to resources generated as part of this deployment. It is for tracking purposes.
#This is generally the long name of the job, which is the hostname + job type + job ID.
prefix = ""

#The name of the AWS batch job definition
batch_job_definition_name = ""

#This is the location of a JSON file that contains an AWS Batch job definition, containing information such as 
#the name of the container to use and resources to allocate. 
#More information can be found here: https://docs.aws.amazon.com/batch/latest/userguide/job_definitions.html
container_properties = ""

#The name of the IAM instance role to be attached to the machines running this batch job. An instance role is a limited role
#applied to EC2 instances to allow them to access designated resources. 
#More information can be found at: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html
iam_instance_role = ""

#The instance profile to attach to attach to EC2 machines. The instance profile is associated with a role, and is the
#resource that is associated with a specific EC2 instance to give it access to desired resources. More information can be
#found at: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html
iam_instance_profile_role = ""

#The role that allows AWS Batch itself (not the EC2 instances) to access needed resources. More information can be found at:
#https://docs.aws.amazon.com/batch/latest/userguide/service_IAM_role.html
aws_batch_service_role = ""

#The name of the security group associated with this batch job
aws_batch_compute_environment_sg = ""

#The name of the batch compute environment to run the jobs in. A job environment consits of ECS container instances that can
#run the job. 
compute_environment_name = ""

#What type of EC2 instance to use in order to handle the job.
instance_type =  ["c4.large"]

priority = 10

#The maximum number of EC2 vCPUs that an environment can use.
max_vcpus = 256

#The minimum number of EC2 vCPUs that an environment should maintain.
min_vcpus = 0

#What type of compute environment to use. Valid selections are [EC2, SPOT]
compute_env_type = "EC2"

#Valid options are [MANAGED, UNMANAGED]
#This controls whether AWS manages spinning up the resources for us, or if we bring our own environment. 
#DO NOT USE UNMANAGED unless you know what you're doing.
compute_type = "MANAGED"

#The EC2 key pair that is used for instances launched in the compute environment.
ec2_key_pair = "giangb"

#The name of the job queue to create as part of this deployment.
batch_job_queue_name = ""

#The name of the SQS queue that will be created as a part of this deployment. The queue is the primary way that different nodes
#communicate that they have completed a part of the batch job, and pass their completed parts to the next stage of the pipeline
sqs_queue_name = ""

#The name of the bucket the results should be output to.
output_bucket_name = ""
